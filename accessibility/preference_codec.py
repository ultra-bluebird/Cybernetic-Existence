"""Pure preference conversion between two fictional implementations.

Python 3.10 or newer.
Dependency: jsonschema with Draft 2020-12 support.

Use the trusted local schema supplied with this format.
Do not accept a schema selected by an imported profile.

No application settings, files, devices, or services are modified.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

import copy
from jsonschema import Draft202012Validator, ValidationError


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

FIELDS = {
    "text_scale_percent": ("display", "text_scale_percent"),
    "contrast": ("display", "contrast"),
    "reduced_motion": ("display", "reduced_motion"),
    "captions_enabled": ("captions", "enabled"),
    "caption_scale_percent": ("captions", "text_scale_percent"),
    "speaker_labels": ("captions", "speaker_labels"),
    "navigation_mode": ("navigation", "mode"),
    "simultaneous_inputs_allowed": (
        "navigation", "simultaneous_inputs_allowed"
    ),
    "dwell_enabled": ("timing", "dwell_selection", "enabled"),
    "dwell_ms": ("timing", "dwell_selection", "duration_ms"),
    "timeout_mode": ("timing", "menu_timeout", "mode"),
    "timeout_ms": ("timing", "menu_timeout", "duration_ms"),
}

BETA = {name: (name, 1) for name in FIELDS}
BETA.update({
    "text_scale_percent": ("text_scale_permille", 10),
    "caption_scale_percent": ("caption_scale_permille", 10),
    "dwell_ms": ("dwell_microseconds", 1000),
    "timeout_ms": ("timeout_microseconds", 1000),
})

INTEGER_FIELDS = {
    "text_scale_percent",
    "caption_scale_percent",
    "dwell_ms",
    "timeout_ms",
}


class ProfileError(ValueError):
    pass


def native_copy(value, depth=0):
    if depth > 16:
        raise ProfileError("input_depth_limit")

    if type(value) is dict:
        if len(value) > 32 or any(type(key) is not str for key in value):
            raise ProfileError("plain_json_object_required")
        return {
            key: native_copy(item, depth + 1)
            for key, item in value.items()
        }

    if type(value) in (str, int, bool, type(None)):
        if type(value) is str and len(value) > 1024:
            raise ProfileError("input_string_limit")
        return value

    raise ProfileError("unsupported_json_type")


class PreferenceCodec:
    def __init__(self, trusted_schema):
        Draft202012Validator.check_schema(trusted_schema)
        self.validator = Draft202012Validator(
            copy.deepcopy(trusted_schema)
        )

    def validate(self, profile):
        snapshot = native_copy(profile)

        try:
            self.validator.validate(snapshot)
        except ValidationError:
            # Avoid echoing imported values into error messages.
            raise ProfileError(
                "profile_does_not_match_v1_schema"
            ) from None

        if type(snapshot) is not dict:
            raise ProfileError("profile_object_required")

        return snapshot

    def to_alpha(self, profile):
        preferences = self.validate(profile)["preferences"]
        result = {}

        for name, path in FIELDS.items():
            value = preferences
            for component in path:
                value = value[component]
            result[name] = value

        return result

    def from_alpha(self, record):
        source = native_copy(record)

        if type(source) is not dict or set(source) != set(FIELDS):
            raise ProfileError("alpha_field_set")

        for name in INTEGER_FIELDS:
            if source[name] is not None and type(source[name]) is not int:
                raise ProfileError("integer_preference_required")

        profile = {
            "format_version": "1.0.0",
            "settings_scope": "menu_and_presentation",
            "format_provenance": {
                "sovereign_attribution": ATTRIBUTION,
                "attribution_use":
                    "format_credit_not_profile_owner_identity",
            },
            "preferences": {},
        }

        for name, path in FIELDS.items():
            target = profile["preferences"]
            for component in path[:-1]:
                target = target.setdefault(component, {})
            target[path[-1]] = source[name]

        return self.validate(profile)

    def to_beta(self, profile):
        source = self.to_alpha(profile)

        return {
            destination: (
                source[name] * scale
                if scale != 1 and source[name] is not None
                else source[name]
            )
            for name, (destination, scale) in BETA.items()
        }

    def from_beta(self, record):
        source = native_copy(record)
        expected = {
            destination for destination, _ in BETA.values()
        }

        if type(source) is not dict or set(source) != expected:
            raise ProfileError("beta_field_set")

        flat = {}

        for name, (destination, scale) in BETA.items():
            value = source[destination]

            if scale != 1 and value is not None:
                if type(value) is not int or value % scale:
                    raise ProfileError(
                        "lossy_unit_conversion_rejected"
                    )
                value //= scale

            flat[name] = value

        return self.from_alpha(flat)
