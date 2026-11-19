#![cfg_attr(not(feature = "std"), no_std)]

use core::fmt;

pub const MAX_CAPABILITY_WINDOWS: usize = 16;
pub const BASIS_POINTS_PER_UNIT: u16 = 10_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct UnitInterval(u16);

impl UnitInterval {
    pub const ZERO: Self = Self(0);
    pub const ONE: Self = Self(BASIS_POINTS_PER_UNIT);

    pub const fn from_basis_points(basis_points: u16) -> Result<Self, ContinuityError> {
        if basis_points > BASIS_POINTS_PER_UNIT {
            return Err(ContinuityError::InvalidUnitInterval);
        }

        Ok(Self(basis_points))
    }

    pub const fn basis_points(self) -> u16 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EvidenceStatus {
    Verified,
    PendingReview,
    Unavailable,
    Rejected,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CapabilityWindow {
    pub starts_at_milliseconds: u32,
    pub ends_at_milliseconds_exclusive: u32,
    pub evidence_status: EvidenceStatus,
    pub satisfied: bool,
}

impl CapabilityWindow {
    pub const fn validate(self) -> Result<(), ContinuityError> {
        if self.ends_at_milliseconds_exclusive <= self.starts_at_milliseconds {
            return Err(ContinuityError::InvalidWindowBounds);
        }

        Ok(())
    }

    pub const fn duration_milliseconds(self) -> u32 {
        self.ends_at_milliseconds_exclusive - self.starts_at_milliseconds
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ContinuityAssessment {
    pub route_start_milliseconds: u32,
    pub route_end_milliseconds_exclusive: u32,
    pub total_duration_milliseconds: u32,
    pub covered_duration_milliseconds: u32,
    pub continuity_ratio: UnitInterval,
    pub uninterrupted: bool,
    pub verified_window_count: u8,
}

pub fn assess_continuity(
    route_start_milliseconds: u32,
    route_end_milliseconds_exclusive: u32,
    windows: &[CapabilityWindow; MAX_CAPABILITY_WINDOWS],
    window_count: usize,
) -> Result<ContinuityAssessment, ContinuityError> {
    if route_end_milliseconds_exclusive <= route_start_milliseconds {
        return Err(ContinuityError::InvalidRouteBounds);
    }

    if window_count > MAX_CAPABILITY_WINDOWS {
        return Err(ContinuityError::TooManyWindows);
    }

    let mut accepted_windows = [CapabilityWindow {
        starts_at_milliseconds: 0,
        ends_at_milliseconds_exclusive: 0,
        evidence_status: EvidenceStatus::Unavailable,
        satisfied: false,
    }; MAX_CAPABILITY_WINDOWS];

    let mut accepted_count = 0usize;

    for window in windows.iter().take(window_count) {
        window.validate()?;

        if window.evidence_status != EvidenceStatus::Verified || !window.satisfied {
            continue;
        }

        let starts_at_milliseconds = window
            .starts_at_milliseconds
            .max(route_start_milliseconds);

        let ends_at_milliseconds_exclusive = window
            .ends_at_milliseconds_exclusive
            .min(route_end_milliseconds_exclusive);

        if ends_at_milliseconds_exclusive <= starts_at_milliseconds {
            continue;
        }

        accepted_windows[accepted_count] = CapabilityWindow {
            starts_at_milliseconds,
            ends_at_milliseconds_exclusive,
            evidence_status: window.evidence_status,
            satisfied: true,
        };

        accepted_count += 1;
    }

    insertion_sort_windows(&mut accepted_windows, accepted_count);

    let mut covered_duration_milliseconds = 0u32;
    let mut cursor_milliseconds = route_start_milliseconds;

    for window in accepted_windows.iter().take(accepted_count) {
        if window.ends_at_milliseconds_exclusive <= cursor_milliseconds {
            continue;
        }

        let effective_start_milliseconds =
            window.starts_at_milliseconds.max(cursor_milliseconds);

        if effective_start_milliseconds > cursor_milliseconds {
            cursor_milliseconds = effective_start_milliseconds;
        }

        let effective_end_milliseconds = window
            .ends_at_milliseconds_exclusive
            .max(cursor_milliseconds);

        let additional_coverage_milliseconds = effective_end_milliseconds
            .checked_sub(cursor_milliseconds)
            .ok_or(ContinuityError::ArithmeticOverflow)?;

        covered_duration_milliseconds = covered_duration_milliseconds
            .checked_add(additional_coverage_milliseconds)
            .ok_or(ContinuityError::ArithmeticOverflow)?;

        cursor_milliseconds = effective_end_milliseconds;

        if cursor_milliseconds >= route_end_milliseconds_exclusive {
            break;
        }
    }

    let total_duration_milliseconds = route_end_milliseconds_exclusive
        .checked_sub(route_start_milliseconds)
        .ok_or(ContinuityError::ArithmeticOverflow)?;

    let continuity_basis_points = ((covered_duration_milliseconds as u64)
        .checked_mul(BASIS_POINTS_PER_UNIT as u64)
        .ok_or(ContinuityError::ArithmeticOverflow)?
        / total_duration_milliseconds as u64) as u16;

    Ok(ContinuityAssessment {
        route_start_milliseconds,
        route_end_milliseconds_exclusive,
        total_duration_milliseconds,
        covered_duration_milliseconds,
        continuity_ratio: UnitInterval::from_basis_points(continuity_basis_points)?,
        uninterrupted: covered_duration_milliseconds == total_duration_milliseconds,
        verified_window_count: accepted_count as u8,
    })
}

fn insertion_sort_windows(
    windows: &mut [CapabilityWindow; MAX_CAPABILITY_WINDOWS],
    window_count: usize,
) {
    let mut index = 1usize;

    while index < window_count {
        let current = windows[index];
        let mut insertion_index = index;

        while insertion_index > 0
            && compare_windows(current, windows[insertion_index - 1]).is_lt()
        {
            windows[insertion_index] = windows[insertion_index - 1];
            insertion_index -= 1;
        }

        windows[insertion_index] = current;
        index += 1;
    }
}

fn compare_windows(left: CapabilityWindow, right: CapabilityWindow) -> core::cmp::Ordering {
    left.starts_at_milliseconds
        .cmp(&right.starts_at_milliseconds)
        .then_with(|| {
            left.ends_at_milliseconds_exclusive
                .cmp(&right.ends_at_milliseconds_exclusive)
        })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContinuityError {
    ArithmeticOverflow,
    InvalidRouteBounds,
    InvalidUnitInterval,
    InvalidWindowBounds,
    TooManyWindows,
}

impl fmt::Display for ContinuityError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ArithmeticOverflow => write!(formatter, "continuity arithmetic overflowed"),
            Self::InvalidRouteBounds => {
                write!(formatter, "route end must be greater than route start")
            }
            Self::InvalidUnitInterval => {
                write!(formatter, "unit interval basis points exceed the valid range")
            }
            Self::InvalidWindowBounds => {
                write!(formatter, "capability window end must be greater than its start")
            }
            Self::TooManyWindows => {
                write!(formatter, "capability window count exceeds fixed embedded capacity")
            }
        }
    }
}
