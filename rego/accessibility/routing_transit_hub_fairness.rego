package augmented_hub.accessibility.routing_transit_hub_fairness

default allow_advisory_planning := false
default route_valid := false
default require_human_review := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

valid_nonnegative(value) {
    is_number(value)
    value >= 0
}

valid_positive(value) {
    is_number(value)
    value > 0
}

weights_valid(weights) {
    every weight in weights {
        valid_unit_interval(weight)
    }

    abs(sum(weights) - 1.0) <= 0.000001
}

route_valid {
    valid_positive(input.route.clear_width_m)
    valid_positive(input.route.minimum_required_width_m)
    input.route.clear_width_m >= input.route.minimum_required_width_m
    input.route.hazard_present == false
    valid_unit_interval(input.route.mapping_quality)
    valid_unit_interval(input.route.freshness_quality)
    valid_unit_interval(input.route.accessibility_review_quality)
    input.route.uncertainty_score <= input.policy.maximum_route_uncertainty
}

route_requires_review {
    input.route.clear_width_m < input.route.minimum_required_width_m
}

route_requires_review {
    input.route.hazard_present == true
}

route_requires_review {
    input.route.uncertainty_score > input.policy.maximum_route_uncertainty
}

transit_fairness_valid {
    every zone in input.transit.zones {
        valid_nonnegative(zone.frequency_per_hour)
        valid_nonnegative(zone.accessible_capacity_per_hour)
        valid_nonnegative(zone.observed_demand)
        valid_nonnegative(zone.unmet_demand)
        valid_nonnegative(zone.essential_trip_demand)
        valid_unit_interval(zone.reliability)
        valid_unit_interval(zone.accessibility_continuity)
        zone.accessible_capacity_per_hour <= zone.nominal_capacity_per_hour
    }
}

hub_capacity_valid {
    every hub in input.hubs {
        valid_nonnegative(hub.visitor_count)
        valid_positive(hub.fire_capacity)
        valid_positive(hub.circulation_capacity)
        valid_positive(hub.seating_capacity)
        valid_positive(hub.mobility_capacity)
        valid_positive(hub.rest_capacity)
        valid_positive(hub.staff_capacity)
        valid_positive(hub.water_capacity)
        valid_positive(hub.cooling_capacity)
        hub.accessible_capacity <= hub.nominal_capacity
    }
}

allow_advisory_planning {
    input.advisory_only == true
    input.automatically_denies_access == false
    input.requires_identity_disclosure == false
    input.requires_disability_disclosure == false
    input.requires_integration_disclosure == false
    input.accessible_explanation_available == true
    input.appeal_or_correction_path_available == true
    weights_valid(input.route.weights)
    transit_fairness_valid
    hub_capacity_valid
}

require_human_review {
    route_requires_review
}

require_human_review {
    not transit_fairness_valid
}

require_human_review {
    not hub_capacity_valid
}

require_human_review {
    input.hub_metrics.utilization_gap > 0.30
}

deny_reason["route selection requires valid accessible clearance and no known hazard"] {
    not route_valid
}

deny_reason["route weights must be community-reviewed and sum to one"] {
    not weights_valid(input.route.weights)
}

deny_reason["transit planning must use accessible capacity rather than nominal seat count alone"] {
    not transit_fairness_valid
}

deny_reason["hub planning must include accessible circulation mobility rest water cooling and staffing capacity"] {
    not hub_capacity_valid
}

deny_reason["public access cannot be denied to optimize utilization metrics"] {
    input.automatically_denies_access != false
}

deny_reason["route transit and hub access cannot require identity disclosure"] {
    input.requires_identity_disclosure != false
}

deny_reason["route transit and hub access cannot require disability disclosure"] {
    input.requires_disability_disclosure != false
}

deny_reason["route transit and hub access cannot require cybernetic integration disclosure"] {
    input.requires_integration_disclosure != false
}

deny_reason["all planning outputs require accessible explanation and correction pathways"] {
    input.accessible_explanation_available != true
}

deny_reason["the planning model is advisory-only"] {
    input.advisory_only != true
}
