from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from typing import Iterable


@dataclass(frozen=True)
class CivicResource:
    resource_type: str
    resource_key: str
    name: str
    service_category: str
    plain_language_summary: str
    current_status: str
    updated_at: str
    expires_at: str
    accessible_entrance: bool
    accessible_restroom: bool
    hearing_loop: bool
    offline_service_path: bool


@dataclass(frozen=True)
class CacheManifestEntry:
    resource_type: str
    resource_key: str
    content_hash: str
    source_updated_at: str
    expires_at: str
    content_version: str


def validate_resource(resource: CivicResource) -> None:
    required_text = (
        resource.resource_type,
        resource.resource_key,
        resource.name,
        resource.service_category,
        resource.plain_language_summary,
        resource.current_status,
        resource.updated_at,
        resource.expires_at,
    )

    if any(not value.strip() for value in required_text):
        raise ValueError("all civic resource text fields must be non-empty")

    updated_at = datetime.fromisoformat(resource.updated_at.replace("Z", "+00:00"))
    expires_at = datetime.fromisoformat(resource.expires_at.replace("Z", "+00:00"))

    if expires_at <= updated_at:
        raise ValueError("expires_at must be later than updated_at")


def resource_to_turtle(resource: CivicResource) -> str:
    validate_resource(resource)

    escaped_name = resource.name.replace('"', '\\"')
    escaped_summary = resource.plain_language_summary.replace('"', '\\"')

    return "\n".join([
        "@prefix civic: <https://augmented-hub.example/ns/civic#> .",
        f'civic:{resource.resource_key} a civic:{resource.resource_type} ;',
        f'  civic:hasName "{escaped_name}" ;',
        f'  civic:hasServiceCategory "{resource.service_category}" ;',
        f'  civic:hasPlainLanguageSummary "{escaped_summary}" ;',
        f'  civic:hasCurrentStatus "{resource.current_status}" ;',
        f'  civic:hasAccessibleEntrance {str(resource.accessible_entrance).lower()} ;',
        f'  civic:hasAccessibleRestroom {str(resource.accessible_restroom).lower()} ;',
        f'  civic:hasHearingLoop {str(resource.hearing_loop).lower()} ;',
        f'  civic:hasOfflineServicePath {str(resource.offline_service_path).lower()} ;',
        f'  civic:updatedAt "{resource.updated_at}" ;',
        f'  civic:expiresAt "{resource.expires_at}" .',
    ])


def build_cache_manifest(
    resources: Iterable[CivicResource],
    content_version: str,
) -> list[CacheManifestEntry]:
    entries: list[CacheManifestEntry] = []

    for resource in resources:
        turtle = resource_to_turtle(resource)
        entries.append(
            CacheManifestEntry(
                resource_type=resource.resource_type,
                resource_key=resource.resource_key,
                content_hash=sha256(turtle.encode("utf-8")).hexdigest(),
                source_updated_at=resource.updated_at,
                expires_at=resource.expires_at,
                content_version=content_version,
            )
        )

    return entries


def eligible_for_offline_cache(resource: CivicResource, now: datetime | None = None) -> bool:
    validate_resource(resource)
    current_time = now or datetime.now(timezone.utc)
    expiration = datetime.fromisoformat(resource.expires_at.replace("Z", "+00:00"))
    return expiration > current_time
