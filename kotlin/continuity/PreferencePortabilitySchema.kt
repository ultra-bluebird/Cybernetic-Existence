package augmentedhub.continuity

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.util.Collections

enum class ProfileField {
    TEXT_FIRST,
    REDUCED_MOTION,
    MANUAL_PACING,
    KEEP_DRAFT_ON_PAUSE,
    SHOW_FAMILIAR_LABELS,
    ASSISTIVE_TECHNOLOGY_CONFIGURATION,
    DEVICE_PAIRING,
    CREDENTIALS,
    MEDICAL_INFORMATION,
    NEURAL_INFORMATION,
    BIOMETRIC_INFORMATION,
    COMPANION_INVENTORY
}

enum class PortabilityCategory {
    PORTABLE, LOCAL_ONLY, FORBIDDEN
}

/**
 * Metadata only. Forbidden/local values are never supplied here.
 * Portable entries use Boolean values.
 */
class PreferenceFieldDeclaration(
    val field: ProfileField,
    val categoryDeclared: PortabilityCategory,
    val portableBooleanValue: Boolean?
) : RedactedContent()

class PortablePreferenceCandidate internal constructor(
    preferences: Map<ProfileField, Boolean>
) : RedactedContent() {
    val schemaVersion = "1"
    val preferences: Map<ProfileField, Boolean> =
        Collections.unmodifiableMap(preferences.toMap())

    val authenticationUsePermitted: Boolean get() = false
    val eligibilityUsePermitted: Boolean get() = false
    val draftContentIncluded: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

class PreferenceSchemaAssessment(
    localOnly: Set<ProfileField>,
    forbidden: Set<ProfileField>,
    misclassified: Set<ProfileField>,
    val candidate: PortablePreferenceCandidate?
) : RedactedContent() {
    val localOnlyFields = Collections.unmodifiableSet(localOnly.toSet())
    val forbiddenFields = Collections.unmodifiableSet(forbidden.toSet())
    val misclassifiedFields =
        Collections.unmodifiableSet(misclassified.toSet())
}

object PreferencePortabilitySchema {
    fun category(field: ProfileField): PortabilityCategory = when (field) {
        ProfileField.TEXT_FIRST,
        ProfileField.REDUCED_MOTION,
        ProfileField.MANUAL_PACING,
        ProfileField.KEEP_DRAFT_ON_PAUSE,
        ProfileField.SHOW_FAMILIAR_LABELS -> PortabilityCategory.PORTABLE

        ProfileField.ASSISTIVE_TECHNOLOGY_CONFIGURATION,
        ProfileField.DEVICE_PAIRING -> PortabilityCategory.LOCAL_ONLY

        else -> PortabilityCategory.FORBIDDEN
    }

    fun prepareSelectedProfile(
        declarations: List<PreferenceFieldDeclaration>,
        selectedPortableFields: Set<ProfileField>
    ): CommonResult<PreferenceSchemaAssessment> {
        if (declarations.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            declarations.map { it.field }.toSet().size != declarations.size
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The preference field inventory is excessive or duplicated."
            )
        }

        val inventory = declarations.toList()
        val declaredFields = inventory.map { it.field }.toSet()

        if (!declaredFields.containsAll(selectedPortableFields) ||
            selectedPortableFields.any {
                category(it) != PortabilityCategory.PORTABLE
            }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The selected export fields are absent or not portable."
            )
        }

        val localOnly = mutableSetOf<ProfileField>()
        val forbidden = mutableSetOf<ProfileField>()
        val misclassified = mutableSetOf<ProfileField>()
        val portable = linkedMapOf<ProfileField, Boolean>()

        for (entry in inventory) {
            val actual = category(entry.field)
            if (actual != entry.categoryDeclared) {
                misclassified += entry.field
            }

            when (actual) {
                PortabilityCategory.PORTABLE -> {
                    val value = entry.portableBooleanValue
                    if (value == null) {
                        return CommonResult(
                            ResultState.INVALID_INPUT,
                            CommonCode.INPUT_CONTRACT_VIOLATION,
                            "A portable preference lacks its Boolean value."
                        )
                    }
                    if (entry.field in selectedPortableFields) {
                        portable[entry.field] = value
                    }
                }

                PortabilityCategory.LOCAL_ONLY -> {
                    localOnly += entry.field
                    if (entry.portableBooleanValue != null) {
                        misclassified += entry.field
                    }
                }

                PortabilityCategory.FORBIDDEN -> {
                    forbidden += entry.field
                }
            }
        }

        val blocked = forbidden.isNotEmpty() || misclassified.isNotEmpty()

        return CommonResult(
            if (blocked) ResultState.NEEDS_REVIEW
            else ResultState.DECLARED_CHECKS_MET,
            if (blocked) CommonCode.REVIEW_REQUIRED
            else CommonCode.DECLARED_LOCAL_CHECKS,
            if (blocked)
                "The profile contains prohibited or misclassified declarations. " +
                    "No portable candidate was produced."
            else
                "Only selected portable preferences were included. " +
                    "Local configuration remains outside this candidate.",
            PreferenceSchemaAssessment(
                localOnly,
                forbidden,
                misclassified,
                if (blocked) null else PortablePreferenceCandidate(portable)
            )
        )
    }
}
