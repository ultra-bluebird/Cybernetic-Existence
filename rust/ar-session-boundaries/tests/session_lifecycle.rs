use ar_session_boundaries::{
    ArSession, ArSessionError, ArSessionState,
};

#[test]
fn session_follows_local_lifecycle_to_purge() {
    let session = ArSession::initiate()
        .activate()
        .expect("user-initiated session can activate")
        .pause()
        .expect("active session can pause")
        .end()
        .expect("paused session can end")
        .purge()
        .expect("ended session can purge");

    assert_eq!(session.state, ArSessionState::Purged);
    assert!(!session.sensors_active);
    assert!(!session.volatile_state_present);
    assert!(!session.persistent_spatial_map_present);
    assert!(!session.cross_session_state_present);
    assert_eq!(session.validate(), Ok(()));
}

#[test]
fn active_state_requires_active_sensors_and_volatile_session_state() {
    let mut session = ArSession::initiate()
        .activate()
        .expect("session activation succeeds");

    session.sensors_active = false;

    assert_eq!(
        session.validate(),
        Err(ArSessionError::InvalidTransition)
    );
}

#[test]
fn initiated_state_cannot_contain_active_sensor_or_session_state() {
    let mut session = ArSession::initiate();
    session.volatile_state_present = true;

    assert_eq!(
        session.validate(),
        Err(ArSessionError::InvalidTransition)
    );
}

#[test]
fn paused_session_stops_sensors_but_preserves_current_session_state() {
    let session = ArSession::initiate()
        .activate()
        .expect("session activation succeeds")
        .pause()
        .expect("active session can pause");

    assert_eq!(session.state, ArSessionState::Paused);
    assert!(!session.sensors_active);
    assert!(session.volatile_state_present);
    assert_eq!(session.validate(), Ok(()));
}

#[test]
fn active_sensors_must_stop_before_ending() {
    let session = ArSession::initiate()
        .activate()
        .expect("session activation succeeds");

    assert_eq!(
        session.end(),
        Err(ArSessionError::SensorStopRequiredBeforeEnd)
    );
}

#[test]
fn background_activation_is_rejected() {
    let mut session = ArSession::initiate();
    session.background_activation_requested = true;

    assert_eq!(
        session.activate(),
        Err(ArSessionError::BackgroundActivationProhibited)
    );
}

#[test]
fn persistent_spatial_maps_are_rejected() {
    let mut session = ArSession::initiate();
    session.persistent_spatial_map_present = true;

    assert_eq!(
        session.activate(),
        Err(ArSessionError::PersistentSpatialMapProhibited)
    );
}

#[test]
fn cross_session_state_is_rejected() {
    let mut session = ArSession::initiate();
    session.cross_session_state_present = true;

    assert_eq!(
        session.activate(),
        Err(ArSessionError::CrossSessionStateProhibited)
    );
}

#[test]
fn external_action_authorization_is_rejected() {
    let mut session = ArSession::initiate();
    session.external_action_authorized = true;

    assert_eq!(
        session.activate(),
        Err(ArSessionError::ExternalActionAuthorizationProhibited)
    );
}

#[test]
fn purged_session_cannot_retain_volatile_state() {
    let mut session = ArSession::initiate()
        .activate()
        .expect("session activation succeeds")
        .pause()
        .expect("active session can pause")
        .end()
        .expect("paused session can end")
        .purge()
        .expect("ended session can purge");

    session.volatile_state_present = true;

    assert_eq!(
        session.validate(),
        Err(ArSessionError::PurgeRequiredAfterEnd)
    );
}

#[test]
fn purged_session_cannot_reactivate() {
    let session = ArSession::initiate()
        .activate()
        .expect("session activation succeeds")
        .pause()
        .expect("active session can pause")
        .end()
        .expect("paused session can end")
        .purge()
        .expect("ended session can purge");

    assert_eq!(
        session.activate(),
        Err(ArSessionError::InvalidTransition)
    );
}
