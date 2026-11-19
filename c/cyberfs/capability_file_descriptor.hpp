#pragma once

#include <chrono>
#include <cstdint>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <string_view>
#include <vector>

namespace augmented_hub::cyberfs {

enum class DataCategory {
    CommunicationPreference,
    PrivacyPreference,
    SessionReceipt,
    AccessibilityPreference
};

enum class ResourceClass {
    PreferenceView,
    SessionReceiptView,
    AccessibilityView
};

enum class DescriptorError {
    InvalidCapability,
    Expired,
    Revoked,
    GenerationMismatch,
    AudienceMismatch,
    PurposeMismatch,
    CategoryDenied,
    ResourceDenied,
    WriteDenied,
    Closed
};

struct Capability {
    std::string subject;
    std::string purpose;
    std::set<DataCategory> allowed_categories;
    std::string audience;
    std::chrono::steady_clock::time_point expires_at;
    std::string revocation_handle;
    std::string policy_version;
    std::uint64_t session_generation{};
};

struct ResourceView {
    ResourceClass resource{};
    std::map<DataCategory, std::string> category_values;
};

struct RedactedView {
    ResourceClass resource{};
    std::map<DataCategory, std::string> visible_values;
    std::uint64_t session_generation{};
    std::string policy_version;
};

class RevocationRegistry {
public:
    void revoke(std::string handle);
    [[nodiscard]] bool is_revoked(std::string_view handle) const;

private:
    std::set<std::string, std::less<>> revoked_handles_;
};

class CapabilityFileDescriptor {
public:
    CapabilityFileDescriptor(
        Capability capability,
        ResourceView resource,
        const RevocationRegistry& revocations,
        std::uint64_t active_generation,
        std::string active_audience,
        std::string required_purpose);

    [[nodiscard]] std::optional<RedactedView> read(
        DescriptorError& error) const;

    [[nodiscard]] bool write(
        std::string_view,
        DescriptorError& error) const;

    void close();

    [[nodiscard]] bool is_open() const noexcept;

private:
    [[nodiscard]] bool capability_valid(
        DescriptorError& error) const;

    Capability capability_;
    ResourceView resource_;
    const RevocationRegistry& revocations_;
    std::uint64_t active_generation_{};
    std::string active_audience_;
    std::string required_purpose_;
    bool open_{true};
};

[[nodiscard]] std::optional<CapabilityFileDescriptor> open_capability_view(
    const Capability& capability,
    const ResourceView& resource,
    const RevocationRegistry& revocations,
    std::uint64_t active_generation,
    std::string active_audience,
    std::string required_purpose,
    DescriptorError& error);

}
