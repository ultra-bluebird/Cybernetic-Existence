package augmented_hub.dashboard.fairness_alert

import rego.v1

default allow_alert_generation := false
default prohibit_individual_action := true

minimum_inclusion_policy_score := 0.50
maximum_hostility_score := 0.60
minimum_data_quality_score := 0.70
minimum_sample_count := 30
maximum_missingness_rate := 0.20

forbidden_input_keys := {
	"address",
	"biometric",
	"device_id",
	"email",
	"fingerprint",
	"health",
	"identity",
	"ip",
	"location",
	"name",
	"neural",
	"phone",
	"precise",
	"telemetry",
	"user_id",
}

required_metric_keys := {
	"inclusion_policy_score",
	"hostility_score",
}

required_quality_keys := {
	"data_quality_score",
	"missingness_rate",
	"sample_count",
}

valid_normalized_score(value) if {
	is_number(value)
	value >= 0
	value <= 1
}

has_all_required_keys(object, keys) if {
	every key in keys {
	_ := object[key]
	}
}

contains_forbidden_key(value) if {
	is_object(value)
	some key, child in value
	key in forbidden_input_keys
}

contains_forbidden_key(value) if {
	is_object(value)
	some _, child in value
	contains_forbidden_key(child)
}

contains_forbidden_key(value) if {
	is_array(value)
	some item in value
	contains_forbidden_key(item)
}

aggregate_only_input if {
	not contains_forbidden_key(input)
}

normalized_metrics(metrics) if {
	is_object(metrics)
	has_all_required_keys(metrics, required_metric_keys)
	valid_normalized_score(metrics.inclusion_policy_score)
	valid_normalized_score(metrics.hostility_score)
}

sufficient_data_quality(metrics) if {
	is_object(metrics.data_quality)
	has_all_required_keys(metrics.data_quality, required_quality_keys)
	valid_normalized_score(metrics.data_quality.data_quality_score)
	valid_normalized_score(metrics.data_quality.missingness_rate)
	is_number(metrics.data_quality.sample_count)
	metrics.data_quality.sample_count >= minimum_sample_count
	metrics.data_quality.data_quality_score >= minimum_data_quality_score
	metrics.data_quality.missingness_rate <= maximum_missingness_rate
}

alert_reasons contains reason if {
	input.metrics.inclusion_policy_score < minimum_inclusion_policy_score
	reason := {
		"code": "inclusion_policy_score_below_threshold",
		"comparison": "below",
		"metric": "inclusion_policy_score",
		"observed_value": input.metrics.inclusion_policy_score,
		"threshold": minimum_inclusion_policy_score,
	}
}

alert_reasons contains reason if {
	input.metrics.hostility_score > maximum_hostility_score
	reason := {
		"code": "hostility_score_above_threshold",
		"comparison": "above",
		"metric": "hostility_score",
		"observed_value": input.metrics.hostility_score,
		"threshold": maximum_hostility_score,
	}
}

has_fairness_signal if {
	count(alert_reasons) > 0
}

allow_alert_generation if {
	is_object(input)
	aggregate_only_input
	normalized_metrics(input.metrics)
	sufficient_data_quality(input.metrics)
	has_fairness_signal
}

data_quality_limitations contains limitation if {
	not is_object(input.metrics.data_quality)
	limitation := "No data-quality object was supplied."
}

data_quality_limitations contains limitation if {
	is_object(input.metrics.data_quality)
	not has_all_required_keys(input.metrics.data_quality, required_quality_keys)
	limitation := "The data-quality object is incomplete."
}

data_quality_limitations contains limitation if {
	is_object(input.metrics.data_quality)
	has_all_required_keys(input.metrics.data_quality, required_quality_keys)
	not valid_normalized_score(input.metrics.data_quality.data_quality_score)
	limitation := "data_quality_score is missing or outside the normalized range."
}

data_quality_limitations contains limitation if {
	is_object(input.metrics.data_quality)
	has_all_required_keys(input.metrics.data_quality, required_quality_keys)
	not valid_normalized_score(input.metrics.data_quality.missingness_rate)
	limitation := "missingness_rate is missing or outside the normalized range."
}

data_quality_limitations contains limitation if {
	is_object(input.metrics.data_quality)
	has_all_required_keys(input.metrics.data_quality, required_quality_keys)
	is_number(input.metrics.data_quality.data_quality_score)
	input.metrics.data_quality.data_quality_score < minimum_data_quality_score
	limitation := "Data quality is below the minimum threshold for alert generation."
}

data_quality_limitations contains limitation if {
	is_object(input.metrics.data_quality)
	has_all_required_keys(input.metrics.data_quality, required_quality_keys)
	is_number(input.metrics.data_quality.missingness_rate)
	input.metrics.data_quality.missingness_rate > maximum_missingness_rate
	limitation := "Missingness exceeds the maximum threshold for alert generation."
}

data_quality_limitations contains limitation if {
	is_object(input.metrics.data_quality)
	has_all_required_keys(input.metrics.data_quality, required_quality_keys)
	is_number(input.metrics.data_quality.sample_count)
	input.metrics.data_quality.sample_count < minimum_sample_count
	limitation := "Aggregate sample count is below the minimum threshold for alert generation."
}

fairness_alert_payload(payload) if {
	allow_alert_generation

	payload := {
		"alert_type": "aggregate_fairness_review",
		"alert_generated": true,
		"data_scope": "aggregate_normalized_dashboard_metrics",
		"message": "Aggregate dashboard metrics require a fairness review. This alert is advisory and must not be used for individual targeting, eligibility, surveillance, punishment, or service restriction.",
		"metrics": {
			"inclusion_policy_score": input.metrics.inclusion_policy_score,
			"hostility_score": input.metrics.hostility_score,
		},
		"quality": {
			"data_quality_score": input.metrics.data_quality.data_quality_score,
			"missingness_rate": input.metrics.data_quality.missingness_rate,
			"sample_count": input.metrics.data_quality.sample_count,
		},
		"prohibited_actions": [
			"individual_targeting",
			"identity_inference",
			"eligibility_determination",
			"service_denial",
			"surveillance",
			"punitive_action",
		],
		"reasons": sort([reason | reason := alert_reasons[_]]),
		"required_next_steps": [
			"Provide an accessible, plain-language explanation of the aggregate signal.",
			"Open a privacy-preserving review workflow with human oversight.",
			"Offer an accessible grievance and correction path.",
			"Assess systemic conditions and remedies without profiling or targeting individuals.",
			"Document uncertainty, data coverage, and any remediation decision.",
		],
	}
}

fairness_alert_payload(payload) if {
	not allow_alert_generation

	payload := {
		"alert_type": "aggregate_fairness_review",
		"alert_generated": false,
		"data_scope": "aggregate_normalized_dashboard_metrics",
		"message": "No fairness alert was generated. The policy requires both a fairness threshold signal and sufficient aggregate data quality.",
		"prohibited_actions": [
			"individual_targeting",
			"identity_inference",
			"eligibility_determination",
			"service_denial",
			"surveillance",
			"punitive_action",
		],
		"quality_limitations": sort([limitation | limitation := data_quality_limitations[_]]),
	}
}
