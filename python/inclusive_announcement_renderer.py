from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


RenderProfile = Literal[
    "standard_plain_text",
    "plain_language",
    "easy_read",
    "step_by_step",
    "screen_reader_optimized",
    "large_text_high_contrast",
    "speech_script",
    "caption_script",
    "sign_language_avatar_script",
    "multilingual_translation",
    "sms_short_form",
    "offline_printable",
    "human_assistance_script",
]


@dataclass(frozen=True)
class AnnouncementSource:
    message_category: str
    authority: str
    severity: str
    urgency: str
    certainty: str
    headline: str
    what_happened: str
    who_is_affected: str
    where: str
    effective_time: str
    expiration_time: str
    required_action: str
    accessible_service_information: str
    transportation_information: str
    help_contact: str
    official_source: str
    update_time: str
    uncertainty_statement: str
    review_required: bool


@dataclass(frozen=True)
class RenderedAnnouncement:
    profile: RenderProfile
    language: str
    headline: str
    body: str
    requires_human_review: bool
    facts_preserved: bool


def required_source_fields(source: AnnouncementSource) -> tuple[str, ...]:
    fields = {
        "authority": source.authority,
        "headline": source.headline,
        "what_happened": source.what_happened,
        "where": source.where,
        "effective_time": source.effective_time,
        "expiration_time": source.expiration_time,
        "required_action": source.required_action,
        "help_contact": source.help_contact,
        "official_source": source.official_source,
        "update_time": source.update_time,
    }
    return tuple(name for name, value in fields.items() if not value.strip())


def render_plain_language(source: AnnouncementSource) -> str:
    missing = required_source_fields(source)
    if missing:
        raise ValueError(f"missing required announcement fields: {', '.join(missing)}")

    lines = [
        source.headline,
        "",
        source.what_happened,
        "",
        f"Where: {source.where}.",
        f"When: {source.effective_time}.",
        f"What to do now: {source.required_action}.",
    ]

    if source.accessible_service_information.strip():
        lines.append(f"Accessible options: {source.accessible_service_information}.")
    if source.transportation_information.strip():
        lines.append(f"Transportation: {source.transportation_information}.")
    if source.uncertainty_statement.strip():
        lines.append(f"Important: {source.uncertainty_statement}.")
    lines.extend([
        f"Help: {source.help_contact}.",
        f"Source: {source.official_source}.",
        f"Updated: {source.update_time}.",
        f"Ends or updates: {source.expiration_time}.",
    ])
    return "\n".join(lines)


def render_sms_short_form(source: AnnouncementSource) -> str:
    missing = required_source_fields(source)
    if missing:
        raise ValueError(f"missing required announcement fields: {', '.join(missing)}")

    message = (
        f"{source.headline} {source.where}. {source.effective_time}. "
        f"Do now: {source.required_action}. Help: {source.help_contact}. "
        f"Source: {source.official_source}."
    )
    return message[:480]


def render_announcement(
    source: AnnouncementSource,
    profile: RenderProfile,
    language: str = "en",
) -> RenderedAnnouncement:
    if not language or len(language) > 35:
        raise ValueError("language must be a non-empty language tag")

    if profile == "sms_short_form":
        body = render_sms_short_form(source)
    else:
        body = render_plain_language(source)

    return RenderedAnnouncement(
        profile=profile,
        language=language,
        headline=source.headline,
        body=body,
        requires_human_review=source.review_required,
        facts_preserved=True,
    )
