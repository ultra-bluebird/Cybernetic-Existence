use crate::error::{PopmathError, PopmathResult};
use crate::units::DurationSeconds;

/// An unambiguous Unix timestamp measured in seconds since the Unix epoch.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct UtcTimestamp(i64);

impl UtcTimestamp {
    /// Creates a UTC timestamp from Unix seconds.
    #[must_use]
    pub const fn from_unix_seconds(seconds: i64) -> Self {
        Self(seconds)
    }

    /// Returns Unix seconds.
    #[must_use]
    pub const fn unix_seconds(self) -> i64 {
        self.0
    }
}

/// A half-open UTC interval from `start` inclusive to `end` exclusive.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TimeWindow {
    start: UtcTimestamp,
    end: UtcTimestamp,
}

impl TimeWindow {
    /// Creates a validated time window.
    pub fn new(start: UtcTimestamp, end: UtcTimestamp) -> PopmathResult<Self> {
        if start > end {
            return Err(PopmathError::InvalidTimeWindow);
        }

        Ok(Self { start, end })
    }

    /// Returns the start timestamp.
    #[must_use]
    pub const fn start(self) -> UtcTimestamp {
        self.start
    }

    /// Returns the end timestamp.
    #[must_use]
    pub const fn end(self) -> UtcTimestamp {
        self.end
    }

    /// Returns duration in seconds.
    pub fn duration(self) -> PopmathResult<DurationSeconds> {
        let seconds = self
            .end
            .unix_seconds()
            .checked_sub(self.start.unix_seconds())
            .ok_or(PopmathError::NumericalInstability {
                component: "time_window_duration",
            })?;

        DurationSeconds::new(seconds as f64)
    }

    /// Returns whether the timestamp is inside the half-open time window.
    #[must_use]
    pub const fn contains(self, timestamp: UtcTimestamp) -> bool {
        timestamp >= self.start && timestamp < self.end
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn window_duration_is_correct() {
        let window = TimeWindow::new(
            UtcTimestamp::from_unix_seconds(100),
            UtcTimestamp::from_unix_seconds(160),
        )
        .expect("valid window");

        assert_eq!(window.duration().expect("duration").get(), 60.0);
    }

    #[test]
    fn reversed_window_is_rejected() {
        let window = TimeWindow::new(
            UtcTimestamp::from_unix_seconds(160),
            UtcTimestamp::from_unix_seconds(100),
        );

        assert_eq!(window, Err(PopmathError::InvalidTimeWindow));
    }
}
