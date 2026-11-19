#[derive(Clone, Copy, Debug)]
pub struct RenalSnapshot {
    pub timestamp_hours: u64,    // monotone hours since epoch
    pub creatinine_mg_dl: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct RenalCorridor {
    pub creatinine_delta_48h_ceiling: f32,  // e.g., 0.3 mg/dL
    pub creatinine_absolute_ceiling: f32,   // hard max
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RenalState {
    ColdStart,         // < 2 snapshots
    BaselineStable,    // delta within corridor
    DeltaElevated,     // approaching ceiling but below USF
    DeltaBreached,     // exceeded USF/adaptive corridor
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GuardVerdict {
    Allow,
    AllowWithBrake,
    Deny,
}
