package org.augmentedhub.equity

data class CommunityBenefit(
    val groupKey: String,
    val groupName: String,
    val population: Long,
    val deliveredBenefitUnits: Double
)

data class GroupEquityBreakdown(
    val groupKey: String,
    val groupName: String,
    val population: Long,
    val deliveredBenefitUnits: Double,
    val benefitPerPerson: Double,
    val equityRatio: Double?,
    val belowFiftyPercentOfAverage: Boolean
)

data class EquityReport(
    val distributionalBenefitEquityIndex: Double?,
    val averageBenefitPerPerson: Double,
    val mandatoryHumanReview: Boolean,
    val remedyPathwayRequired: Boolean,
    val outcomeCode: String,
    val groups: List<GroupEquityBreakdown>
)

fun calculateDistributionalBenefitEquity(
    benefits: List<CommunityBenefit>
): EquityReport {
    require(benefits.isNotEmpty()) {
        "At least one community-group benefit record is required."
    }

    require(benefits.map { it.groupKey }.toSet().size == benefits.size) {
        "Each groupKey must be unique."
    }

    benefits.forEach { benefit ->
        require(benefit.groupKey.isNotBlank()) {
            "groupKey must not be blank."
        }
        require(benefit.groupName.isNotBlank()) {
            "groupName must not be blank."
        }
        require(benefit.population > 0L) {
            "population must be greater than zero for group ${benefit.groupKey}."
        }
        require(benefit.deliveredBenefitUnits.isFinite()) {
            "deliveredBenefitUnits must be finite for group ${benefit.groupKey}."
        }
        require(benefit.deliveredBenefitUnits >= 0.0) {
            "deliveredBenefitUnits must not be negative for group ${benefit.groupKey}."
        }
    }

    val totalPopulation = benefits.sumOf { it.population }
    val totalBenefits = benefits.sumOf { it.deliveredBenefitUnits }
    val averageBenefitPerPerson = totalBenefits / totalPopulation.toDouble()

    val groupBreakdowns = benefits.map { benefit ->
        val benefitPerPerson =
            benefit.deliveredBenefitUnits / benefit.population.toDouble()

        val equityRatio = if (averageBenefitPerPerson > 0.0) {
            benefitPerPerson / averageBenefitPerPerson
        } else {
            null
        }

        GroupEquityBreakdown(
            groupKey = benefit.groupKey,
            groupName = benefit.groupName,
            population = benefit.population,
            deliveredBenefitUnits = benefit.deliveredBenefitUnits,
            benefitPerPerson = benefitPerPerson,
            equityRatio = equityRatio,
            belowFiftyPercentOfAverage = equityRatio == null || equityRatio < 0.50
        )
    }

    val dbei = groupBreakdowns
        .mapNotNull { it.equityRatio }
        .minOrNull()

    val reviewRequired = dbei == null || dbei < 0.50

    return EquityReport(
        distributionalBenefitEquityIndex = dbei,
        averageBenefitPerPerson = averageBenefitPerPerson,
        mandatoryHumanReview = reviewRequired,
        remedyPathwayRequired = reviewRequired,
        outcomeCode = when {
            dbei == null -> "INSUFFICIENT_BENEFIT_BASELINE_REVIEW_REQUIRED"
            dbei < 0.50 -> "DBEI_BELOW_THRESHOLD_REMEDY_REQUIRED"
            else -> "DBEI_THRESHOLD_NOT_TRIGGERED"
        },
        groups = groupBreakdowns
    )
}
