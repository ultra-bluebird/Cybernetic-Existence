use ar_session_boundaries::{
    inbound_data_allowed, outbound_data_allowed, validate_inbound_data,
    validate_outbound_data, validate_outbound_report, InfrastructureInboundData,
    InfrastructureOutboundData, OutboundReportDeclaration, SmartCityBoundaryError,
};

#[test]
fn permits_public_accessible_route_notice() {
    assert!(inbound_data_allowed(
        InfrastructureInboundData::PublicAccessibleRouteNotice
    ));

    assert_eq!(
        validate_inbound_data(
            InfrastructureInboundData::PublicAccessibleRouteNotice
        ),
        Ok(())
    );
}

#[test]
fn rejects_location_history_from_infrastructure() {
    assert!(!inbound_data_allowed(
        InfrastructureInboundData::LocationHistory
    ));

    assert_eq!(
        validate_inbound_data(InfrastructureInboundData::LocationHistory),
        Err(SmartCityBoundaryError::InboundDataProhibited)
    );
}

#[test]
fn rejects_identity_transmission() {
    assert!(!outbound_data_allowed(
        InfrastructureOutboundData::Identity
    ));

    assert_eq!(
        validate_outbound_data(InfrastructureOutboundData::Identity),
        Err(SmartCityBoundaryError::OutboundDataProhibited)
    );
}

#[test]
fn validates_user_reviewed_local_report_declaration() {
    let declaration = OutboundReportDeclaration {
        user_initiated: true,
        user_review_before_submission: true,
        purpose_declared: true,
        destination_declared: true,
        retention_declared: true,
        correction_or_withdrawal_path_available: true,
        external_action_authorized: false,
    };

    assert_eq!(validate_outbound_report(declaration), Ok(()));
}

#[test]
fn rejects_external_action_authority_for_reports() {
    let declaration = OutboundReportDeclaration {
        user_initiated: true,
        user_review_before_submission: true,
        purpose_declared: true,
        destination_declared: true,
        retention_declared: true,
        correction_or_withdrawal_path_available: true,
        external_action_authorized: true,
    };

    assert_eq!(
        validate_outbound_report(declaration),
        Err(SmartCityBoundaryError::ExternalActionAuthorizationProhibited)
    );
}
