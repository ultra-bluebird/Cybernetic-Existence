#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SimulationStatus {
    CoherenceSimulationAvailable,
    CoherenceReviewRequired,
    InsufficientSimulationContext,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BftConfiguration {
    pub simulated_agent_count: u32,
    pub assumed_faulty_agent_count: u32,
    pub advisory_only: bool,
    pub human_review_required: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct BftAssessment {
    pub status: SimulationStatus,
    pub maximum_tolerable_faults: u32,
    pub required_quorum: u32,
    pub coherence_score: Option<f64>,
    pub explanation: String,
}

pub fn maximum_tolerable_faults(simulated_agent_count: u32) -> Option<u32> {
    if simulated_agent_count < 4 {
        return None;
    }

    Some((simulated_agent_count - 1) / 3)
}

pub fn required_quorum_for_faults(assumed_faulty_agent_count: u32) -> u32 {
    assumed_faulty_agent_count
        .checked_mul(2)
        .and_then(|value| value.checked_add(1))
        .expect("bounded simulation inputs must not overflow")
}

pub fn coherence_score(simulated_states: &[u8]) -> Option<f64> {
    if simulated_states.is_empty() {
        return None;
    }

    let mut counts = [0_u32; 256];
    for state in simulated_states {
        counts[*state as usize] += 1;
    }

    let majority_count = counts.into_iter().max().unwrap_or(0);
    Some(majority_count as f64 / simulated_states.len() as f64)
}

pub fn assess_bft_coherence(
    configuration: &BftConfiguration,
    simulated_states: &[u8],
) -> BftAssessment {
    if !configuration.advisory_only || !configuration.human_review_required {
        return BftAssessment {
            status: SimulationStatus::CoherenceReviewRequired,
            maximum_tolerable_faults: 0,
            required_quorum: 0,
            coherence_score: None,
            explanation: (
                "The model must remain advisory-only and subject to human review. "
                "No simulated consensus assessment is available."
            )
            .to_owned(),
        };
    }

    let Some(maximum_faults) =
        maximum_tolerable_faults(configuration.simulated_agent_count)
    else {
        return BftAssessment {
            status: SimulationStatus::InsufficientSimulationContext,
            maximum_tolerable_faults: 0,
            required_quorum: 0,
            coherence_score: None,
            explanation: (
                "At least four simulated agents are required before the 3f + 1 "
                "Byzantine-fault-tolerance relation can be evaluated."
            )
            .to_owned(),
        };
    };

    let required_quorum =
        required_quorum_for_faults(configuration.assumed_faulty_agent_count);

    if configuration.assumed_faulty_agent_count > maximum_faults {
        return BftAssessment {
            status: SimulationStatus::CoherenceReviewRequired,
            maximum_tolerable_faults: maximum_faults,
            required_quorum,
            coherence_score: coherence_score(simulated_states),
            explanation: (
                "The assumed faulty-agent count exceeds the modeled BFT threshold. "
                "This is a simulation review result, not a real-world fault finding."
            )
            .to_owned(),
        };
    }

    if simulated_states.len() != configuration.simulated_agent_count as usize {
        return BftAssessment {
            status: SimulationStatus::InsufficientSimulationContext,
            maximum_tolerable_faults: maximum_faults,
            required_quorum,
            coherence_score: None,
            explanation: (
                "The simulated state count does not match the configured agent count."
            )
            .to_owned(),
        };
    }

    let score = coherence_score(simulated_states);

    BftAssessment {
        status: SimulationStatus::CoherenceSimulationAvailable,
        maximum_tolerable_faults: maximum_faults,
        required_quorum,
        coherence_score: score,
        explanation: (
            "This result describes an abstract BFT-coherence simulation only. "
            "It does not identify or control real nodes, devices, companions, "
            "or communication systems."
        )
        .to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_agents_tolerate_one_modeled_fault() {
        assert_eq!(maximum_tolerable_faults(4), Some(1));
    }

    #[test]
    fn seven_agents_tolerate_two_modeled_faults() {
        assert_eq!(maximum_tolerable_faults(7), Some(2));
    }

    #[test]
    fn coherence_is_one_when_all_states_match() {
        assert_eq!(coherence_score(&[4, 4, 4, 4]), Some(1.0));
    }

    #[test]
    fn coherence_reports_majority_fraction() {
        assert_eq!(coherence_score(&[1, 1, 1, 2]), Some(0.75));
    }

    #[test]
    fn excessive_fault_assumption_requires_review() {
        let configuration = BftConfiguration {
            simulated_agent_count: 4,
            assumed_faulty_agent_count: 2,
            advisory_only: true,
            human_review_required: true,
        };

        let result = assess_bft_coherence(&configuration, &[1, 1, 2, 3]);

        assert_eq!(result.status, SimulationStatus::CoherenceReviewRequired);
    }
}
