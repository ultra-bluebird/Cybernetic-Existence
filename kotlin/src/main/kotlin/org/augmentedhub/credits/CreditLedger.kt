package org.augmentedhub.credits

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant

data class AccountingPeriod(
    val periodKey: String,
    val start: Instant,
    val end: Instant
) {
    init {
        require(periodKey.isNotBlank()) {
            "periodKey must not be blank."
        }

        require(end.isAfter(start)) {
            "Accounting period end must be after start."
        }
    }
}

data class Credit(
    val creditKey: String,
    val projectKey: String,
    val period: AccountingPeriod,
    val availableUnits: BigDecimal,
    val status: CreditStatus
) {
    init {
        require(creditKey.isNotBlank()) {
            "creditKey must not be blank."
        }

        require(projectKey.isNotBlank()) {
            "projectKey must not be blank."
        }

        require(availableUnits >= BigDecimal.ZERO) {
            "availableUnits must not be negative."
        }
    }
}

enum class CreditStatus {
    ISSUED,
    RETIRED,
    VOID
}

data class HarmOffsetRequest(
    val requestKey: String,
    val projectKey: String,
    val harmPeriod: AccountingPeriod,
    val requestedUnits: BigDecimal
) {
    init {
        require(requestKey.isNotBlank()) {
            "requestKey must not be blank."
        }

        require(projectKey.isNotBlank()) {
            "projectKey must not be blank."
        }

        require(requestedUnits > BigDecimal.ZERO) {
            "requestedUnits must be greater than zero."
        }
    }
}

data class CreditUseDecision(
    val approved: Boolean,
    val reasonCode: String,
    val remainingCreditUnits: BigDecimal
)

class CreditLedger {
    fun applyOffset(
        credit: Credit,
        request: HarmOffsetRequest
    ): CreditUseDecision {
        require(credit.status == CreditStatus.ISSUED) {
            "Only issued credits may be considered for offset."
        }

        if (credit.projectKey != request.projectKey) {
            return CreditUseDecision(
                approved = false,
                reasonCode = "CREDIT_PROJECT_MISMATCH",
                remainingCreditUnits = credit.availableUnits
            )
        }

        if (credit.period.periodKey != request.harmPeriod.periodKey) {
            return CreditUseDecision(
                approved = false,
                reasonCode = "CREDIT_ACCOUNTING_PERIOD_MISMATCH",
                remainingCreditUnits = credit.availableUnits
            )
        }

        if (request.requestedUnits > credit.availableUnits) {
            return CreditUseDecision(
                approved = false,
                reasonCode = "CREDIT_INSUFFICIENT_BALANCE",
                remainingCreditUnits = credit.availableUnits
            )
        }

        val remaining = credit.availableUnits
            .subtract(request.requestedUnits)
            .setScale(6, RoundingMode.HALF_EVEN)

        return CreditUseDecision(
            approved = true,
            reasonCode = "CREDIT_OFFSET_APPROVED_SAME_PERIOD",
            remainingCreditUnits = remaining
        )
    }
}
