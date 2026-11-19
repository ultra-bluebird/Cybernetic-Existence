package augmentedhub.continuity

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.time.Instant
import java.util.Collections

enum class MaterialChangeFacet {
    PRIVACY,
    RETENTION,
    INTERACTION,
    ACCESSIBLE_FALLBACK,
    CONSENT,
    EXTERNAL_ACTION_AUTHORITY,
    NON_INTERFERENCE,
    DEPENDENCY_INVENTORY,
    RUNTIME_DEPENDENCIES,
    RUNTIME_CONFIGURATION,
    PERMISSION_SCOPES,
    NOTIFICATION_BEHAVIOR,
    DEPENDENCY_GRAPH,
    HIDDEN_FIELD_DECLARATIONS
}

enum class FacetDisposition {
    ACCEPTED_DECLARED,
    REJECTED_DECLARED,
    NOT_ESTABLISHED
}

class FacetManifest(
    val artifactSha256: String,
    commitments: Map<MaterialChangeFacet, String>
) : RedactedContent() {
    val commitments =
        Collections.unmodifiableMap(commitments.toMap())
}

class FacetReviewRecord(
    val facet: MaterialChangeFacet,
    val priorArtifactSha256: String,
    val proposedArtifactSha256: String,
    val priorFacetSha256: String,
    val proposedFacetSha256: String,
    val disposition: FacetDisposition,
    val reviewReference: String,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent()

class UnclassifiedArtifactReview(
    val priorArtifactSha256: String,
    val proposedArtifactSha256: String,
    val disposition: FacetDisposition,
    val reviewReference: String,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent()

class MaterialFacetAssessment(
    changed: Set<MaterialChangeFacet>,
    reviewed: Set<MaterialChangeFacet>,
    unresolved: Set<MaterialChangeFacet>,
    rejected: Set<MaterialChangeFacet>
) : RedactedContent() {
    val schemaVersion = "1"
    val changedFacets = Collections.unmodifiableSet(changed.toSet())
    val currentReviewedFacets = Collections.unmodifiableSet(reviewed.toSet())
    val unresolvedFacets = Collections.unmodifiableSet(unresolved.toSet())
    val rejectedFacets = Collections.unmodifiableSet(rejected.toSet())

    val sourceBehaviorInspected: Boolean get() = false
    val deploymentAuthorized: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object MaterialChangeFacets {
    private val digest = Regex("sha256:[0-9a-f]{64}")

    private fun referenceAccepted(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    fun review(
        prior: FacetManifest,
        proposed: FacetManifest,
        records: List<FacetReviewRecord>,
        unclassifiedReview: UnclassifiedArtifactReview?,
        now: Instant
    ): CommonResult<MaterialFacetAssessment> {
        val required = MaterialChangeFacet.entries.toSet()

        if (!digest.matches(prior.artifactSha256) ||
            !digest.matches(proposed.artifactSha256) ||
            prior.commitments.keys != required ||
            proposed.commitments.keys != required ||
            (prior.commitments.values + proposed.commitments.values)
                .any { !digest.matches(it) } ||
            records.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            records.any {
                !digest.matches(it.priorArtifactSha256) ||
                    !digest.matches(it.proposedArtifactSha256) ||
                    !digest.matches(it.priorFacetSha256) ||
                    !digest.matches(it.proposedFacetSha256) ||
                    !referenceAccepted(it.reviewReference) ||
                    it.validUntil <= it.validFrom
            } ||
            (unclassifiedReview != null &&
                (!digest.matches(unclassifiedReview.priorArtifactSha256) ||
                    !digest.matches(unclassifiedReview.proposedArtifactSha256) ||
                    !referenceAccepted(unclassifiedReview.reviewReference) ||
                    unclassifiedReview.validUntil <=
                        unclassifiedReview.validFrom))
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The facet manifests or review records are invalid."
            )
        }

        val changed = required.filter {
            prior.commitments[it] != proposed.commitments[it]
        }.toSet()
        val reviewed = mutableSetOf<MaterialChangeFacet>()
        val unresolved = mutableSetOf<MaterialChangeFacet>()
        val rejected = mutableSetOf<MaterialChangeFacet>()
        var conflict = false

        for (facet in required) {
            val submitted = records.filter { it.facet == facet }

            // Rejections are retained for review, even in conflicting packages.
            if (submitted.any {
                it.disposition == FacetDisposition.REJECTED_DECLARED
            }) rejected += facet

            val matching = submitted.filter {
                it.priorArtifactSha256 == prior.artifactSha256 &&
                    it.proposedArtifactSha256 == proposed.artifactSha256 &&
                    it.priorFacetSha256 == prior.commitments[facet] &&
                    it.proposedFacetSha256 == proposed.commitments[facet]
            }

            if (matching.size != 1) {
                unresolved += facet
                if (matching.size > 1) conflict = true
                continue
            }

            val record = matching.single()
            if (now < record.validFrom || now >= record.validUntil ||
                record.disposition != FacetDisposition.ACCEPTED_DECLARED ||
                facet in rejected
            ) {
                unresolved += facet
            } else {
                reviewed += facet
            }
        }

        val artifactChanged =
            prior.artifactSha256 != proposed.artifactSha256
        val inconsistentBinding = !artifactChanged && changed.isNotEmpty()
        val unclassifiedChange = artifactChanged && changed.isEmpty()

        val extraBound = unclassifiedReview?.let {
            it.priorArtifactSha256 == prior.artifactSha256 &&
                it.proposedArtifactSha256 == proposed.artifactSha256 &&
                now >= it.validFrom && now < it.validUntil
        } ?: false

        val extraRejected = unclassifiedReview?.disposition ==
            FacetDisposition.REJECTED_DECLARED

        val extraAccepted =
            extraBound &&
                unclassifiedReview?.disposition ==
                    FacetDisposition.ACCEPTED_DECLARED

        val state = when {
            inconsistentBinding || conflict || rejected.isNotEmpty() ||
                extraRejected -> ResultState.NEEDS_REVIEW
            unclassifiedChange && !extraAccepted -> ResultState.NEEDS_REVIEW
            unresolved.isNotEmpty() -> ResultState.NOT_ESTABLISHED
            else -> ResultState.DECLARED_CHECKS_MET
        }

        return CommonResult(
            state,
            when (state) {
                ResultState.NEEDS_REVIEW -> CommonCode.REVIEW_REQUIRED
                ResultState.NOT_ESTABLISHED -> CommonCode.EVIDENCE_UNAVAILABLE
                else -> CommonCode.DECLARED_LOCAL_CHECKS
            },
            "This result evaluates exact facet-review declarations. " +
                "It does not classify source behavior, authenticate reviewers, " +
                "or authorize deployment.",
            MaterialFacetAssessment(changed, reviewed, unresolved, rejected)
        )
    }
}
