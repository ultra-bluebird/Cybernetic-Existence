TEACH concept = {
  name: "continuity-preserving documentation",
  definition: "Keep prior records available for review while adding corrections as new records.",
  examples: [
    "A corrected note links to the earlier note instead of replacing it.",
    "An uncertain report remains marked uncertain until reviewed."
  ],
  constraints: [
    "Do not infer identity, health, capability, or credibility.",
    "Do not require technical, medical, biometric, device, or location disclosure.",
    "Do not convert this concept into eligibility, ranking, allocation, enforcement, or control.",
    "Preserve correction, appeal, human fallback, and accessible explanation."
  ],
  priority: 0.95,
  uncertainty: 0.15,
  review_interval: "host-adjustable",
  accessibility_mode: "SCREENLESS_COMPATIBLE",
  correction_route: "AVAILABLE",
  human_review: "REQUIRED"
}
