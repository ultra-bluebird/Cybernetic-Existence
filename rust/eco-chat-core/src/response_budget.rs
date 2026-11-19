#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProviderMode {
    LocalExplanationOnly,
    LocalVerifiedToolsOnly,
    ApprovedRetrieval,
    FullApprovedRoutes,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ResponseBudget {
    pub max_tool_calls: u8,
    pub max_output_tokens: u32,
    pub provider_mode: ProviderMode,
    pub requires_human_review_for_remote: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ToleranceRadius(pub f64);

impl ToleranceRadius {
    pub fn new(value: f64) -> Result<Self, &'static str> {
        if !value.is_finite() {
            return Err("tolerance radius must be finite");
        }

        if !(0.0..=1.0).contains(&value) {
            return Err("tolerance radius must be in the inclusive range [0, 1]");
        }

        Ok(Self(value))
    }
}

pub fn response_budget_for_tolerance(
    tolerance: ToleranceRadius,
    current_request_risk: f64,
) -> Result<ResponseBudget, &'static str> {
    if !current_request_risk.is_finite() {
        return Err("current request risk must be finite");
    }

    if !(0.0..=1.0).contains(&current_request_risk) {
        return Err("current request risk must be in the inclusive range [0, 1]");
    }

    if current_request_risk >= 0.75 {
        return Ok(ResponseBudget {
            max_tool_calls: 0,
            max_output_tokens: 600,
            provider_mode: ProviderMode::LocalExplanationOnly,
            requires_human_review_for_remote: true,
        });
    }

    let budget = if tolerance.0 < 0.25 {
        ResponseBudget {
            max_tool_calls: 0,
            max_output_tokens: 600,
            provider_mode: ProviderMode::LocalExplanationOnly,
            requires_human_review_for_remote: true,
        }
    } else if tolerance.0 < 0.50 {
        ResponseBudget {
            max_tool_calls: 1,
            max_output_tokens: 1_000,
            provider_mode: ProviderMode::LocalVerifiedToolsOnly,
            requires_human_review_for_remote: true,
        }
    } else if tolerance.0 < 0.75 {
        ResponseBudget {
            max_tool_calls: 2,
            max_output_tokens: 1_600,
            provider_mode: ProviderMode::ApprovedRetrieval,
            requires_human_review_for_remote: true,
        }
    } else {
        ResponseBudget {
            max_tool_calls: 3,
            max_output_tokens: 2_400,
            provider_mode: ProviderMode::FullApprovedRoutes,
            requires_human_review_for_remote: false,
        }
    };

    Ok(budget)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lower_tolerance_limits_optional_system_actions() {
        let low = response_budget_for_tolerance(
            ToleranceRadius::new(0.10).expect("valid tolerance"),
            0.20,
        )
        .expect("valid request risk");

        assert_eq!(low.max_tool_calls, 0);
        assert_eq!(low.max_output_tokens, 600);
        assert_eq!(low.provider_mode, ProviderMode::LocalExplanationOnly);
    }

    #[test]
    fn higher_tolerance_allows_more_approved_capacity() {
        let high = response_budget_for_tolerance(
            ToleranceRadius::new(0.90).expect("valid tolerance"),
            0.20,
        )
        .expect("valid request risk");

        assert_eq!(high.max_tool_calls, 3);
        assert_eq!(high.max_output_tokens, 2_400);
        assert_eq!(high.provider_mode, ProviderMode::FullApprovedRoutes);
    }

    #[test]
    fn current_high_risk_overrides_tolerance() {
        let budget = response_budget_for_tolerance(
            ToleranceRadius::new(1.0).expect("valid tolerance"),
            0.80,
        )
        .expect("valid request risk");

        assert_eq!(budget.max_tool_calls, 0);
        assert_eq!(budget.max_output_tokens, 600);
        assert!(budget.requires_human_review_for_remote);
    }
}
