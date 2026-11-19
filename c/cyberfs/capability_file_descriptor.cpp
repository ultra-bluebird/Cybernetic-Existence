#include "capability_file_descriptor.hpp"

#include <utility>

namespace augmented_hub::cyberfs {

void RevocationRegistry::revoke(std::string handle) {
    if (!handle.empty()) {
        revoked_handles_.insert(std::move(handle));
    }
}

bool RevocationRegistry::is_revoked(std::string_view handle) const {
    return revoked_handles_.contains(handle);
}

CapabilityFileDescriptor::CapabilityFileDescriptor(
    Capability capability,
    ResourceView resource,
    const RevocationRegistry& revocations,
    std::uint64_t active_generation,
    std::string active_audience,
    std::string required_purpose)
    : capability_(std::move(capability)),
      resource_(std::move(resource)),
      revocations_(revocations),
      active_generation_(active_generation),
      active_audience_(std::move(active_audience)),
      required_purpose_(std::move(required_purpose)) {}

std::optional<RedactedView> CapabilityFileDescriptor::read(
    DescriptorError& error) const {
    if (!open_) {
        error = DescriptorError::Closed;
        return std::nullopt;
    }

    if (!capability_valid(error)) {
        return std::nullopt;
    }

    RedactedView result{
        .resource = resource_.resource,
        .visible_values = {},
        .session_generation = capability_.session_generation,
        .policy_version = capability_.policy_version
    };

    for (const auto& [category, value] : resource_.category_values) {
        if (capability_.allowed_categories.contains(category)) {
            result.visible_values.emplace(category, value);
        }
    }

    if (result.visible_values.empty()) {
        error = DescriptorError::CategoryDenied;
        return std::nullopt;
    }

    error = DescriptorError::InvalidCapability;
    return result;
}

bool CapabilityFileDescriptor::write(
    std::string_view,
    DescriptorError& error) const {
    error = DescriptorError::WriteDenied;
    return false;
}

void CapabilityFileDescriptor::close() {
    open_ = false;
}

bool CapabilityFileDescriptor::is_open() const noexcept {
    return open_;
}

bool CapabilityFileDescriptor::capability_valid(
    DescriptorError& error) const {
    if (capability_.subject.empty()
        || capability_.purpose.empty()
        || capability_.audience.empty()
        || capability_.revocation_handle.empty()
        || capability_.policy_version.empty()
        || capability_.allowed_categories.empty()
        || capability_.session_generation == 0) {
        error = DescriptorError::InvalidCapability;
        return false;
    }

    if (std::chrono::steady_clock::now() >= capability_.expires_at) {
        error = DescriptorError::Expired;
        return false;
    }

    if (revocations_.is_revoked(capability_.revocation_handle)) {
        error = DescriptorError::Revoked;
        return false;
    }

    if (capability_.session_generation != active_generation_) {
        error = DescriptorError::GenerationMismatch;
        return false;
    }

    if (capability_.audience != active_audience_) {
        error = DescriptorError::AudienceMismatch;
        return false;
    }

    if (capability_.purpose != required_purpose_) {
        error = DescriptorError::PurposeMismatch;
        return false;
    }

    return true;
}

std::optional<CapabilityFileDescriptor> open_capability_view(
    const Capability& capability,
    const ResourceView& resource,
    const RevocationRegistry& revocations,
    std::uint64_t active_generation,
    std::string active_audience,
    std::string required_purpose,
    DescriptorError& error) {
    CapabilityFileDescriptor descriptor(
        capability,
        resource,
        revocations,
        active_generation,
        std::move(active_audience),
        std::move(required_purpose));

    if (!descriptor.read(error).has_value()) {
        return std::nullopt;
    }

    return descriptor;
}

}
