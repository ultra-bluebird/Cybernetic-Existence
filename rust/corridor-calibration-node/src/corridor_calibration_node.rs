#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BiasEstimate {
    pub temperature_c: f32,
    pub humidity_percent: f32,
    pub temperature_variance: f32,
    pub humidity_variance: f32,
    pub link_confidence: f32,
    pub fresh: bool,
    pub gradient_model_version: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CalibrationState {
    pub true_temperature_c: f32,
    pub true_humidity_percent: f32,
    pub bias_temperature_c: f32,
    pub bias_humidity_percent: f32,
    pub bias_temperature_variance: f32,
    pub bias_humidity_variance: f32,
    pub gradient_model_version: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CalibratedReading {
    pub temperature_c: f32,
    pub humidity_percent: f32,
    pub calibration_confidence: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConsensusSummary {
    pub accepted_neighbors: usize,
    pub ignored_neighbors: usize,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CalibrationError {
    InvalidInitialState,
    InvalidLocalMeasurement,
    InvalidConsensusGain,
}

impl CalibrationState {
    pub fn new(
        true_temperature_c: f32,
        true_humidity_percent: f32,
        bias_temperature_c: f32,
        bias_humidity_percent: f32,
        bias_temperature_variance: f32,
        bias_humidity_variance: f32,
        gradient_model_version: u32,
    ) -> Result<Self, CalibrationError> {
        let state = Self {
            true_temperature_c,
            true_humidity_percent,
            bias_temperature_c,
            bias_humidity_percent,
            bias_temperature_variance,
            bias_humidity_variance,
            gradient_model_version,
        };

        if !state.is_valid() {
            return Err(CalibrationError::InvalidInitialState);
        }

        Ok(state)
    }

    pub fn update_local(
        &mut self,
        raw_temperature_c: f32,
        raw_humidity_percent: f32,
        temperature_variance: f32,
        humidity_variance: f32,
    ) -> Result<(), CalibrationError> {
        if !raw_temperature_c.is_finite()
            || !raw_humidity_percent.is_finite()
            || !temperature_variance.is_finite()
            || !humidity_variance.is_finite()
            || !(0.0..=100.0).contains(&raw_humidity_percent)
            || temperature_variance <= 0.0
            || humidity_variance <= 0.0
        {
            return Err(CalibrationError::InvalidLocalMeasurement);
        }

        let temperature_gain = self.bias_temperature_variance
            / (self.bias_temperature_variance + temperature_variance);
        let humidity_gain =
            self.bias_humidity_variance / (self.bias_humidity_variance + humidity_variance);

        let predicted_temperature = self.true_temperature_c + self.bias_temperature_c;
        let predicted_humidity = self.true_humidity_percent + self.bias_humidity_percent;

        self.bias_temperature_c += temperature_gain * (raw_temperature_c - predicted_temperature);
        self.bias_humidity_percent += humidity_gain * (raw_humidity_percent - predicted_humidity);

        self.bias_temperature_variance =
            ((1.0 - temperature_gain) * self.bias_temperature_variance + 0.001).max(1.0e-6);
        self.bias_humidity_variance =
            ((1.0 - humidity_gain) * self.bias_humidity_variance + 0.002).max(1.0e-6);

        self.true_temperature_c = raw_temperature_c - self.bias_temperature_c;
        self.true_humidity_percent = raw_humidity_percent - self.bias_humidity_percent;

        Ok(())
    }

    pub fn consensus_bias(
        &mut self,
        neighbors: &[BiasEstimate],
        consensus_gain: f32,
    ) -> Result<ConsensusSummary, CalibrationError> {
        if !consensus_gain.is_finite() || !(0.0..=1.0).contains(&consensus_gain) {
            return Err(CalibrationError::InvalidConsensusGain);
        }

        let mut total_weight = 0.0_f32;
        let mut temperature_correction = 0.0_f32;
        let mut humidity_correction = 0.0_f32;
        let mut accepted_neighbors = 0_usize;

        for neighbor in neighbors {
            if !is_eligible_neighbor(neighbor, self.gradient_model_version) {
                continue;
            }

            let uncertainty =
                (neighbor.temperature_variance + neighbor.humidity_variance).max(1.0e-6);
            let weight = neighbor.link_confidence / uncertainty;

            total_weight += weight;
            temperature_correction += weight * (neighbor.temperature_c - self.bias_temperature_c);
            humidity_correction += weight * (neighbor.humidity_percent - self.bias_humidity_percent);
            accepted_neighbors += 1;
        }

        if total_weight > 0.0 {
            self.bias_temperature_c += consensus_gain * temperature_correction / total_weight;
            self.bias_humidity_percent += consensus_gain * humidity_correction / total_weight;

            let consensus_variance = (1.0 / total_weight).max(1.0e-6);
            self.bias_temperature_variance =
                self.bias_temperature_variance.min(consensus_variance);
            self.bias_humidity_variance =
                self.bias_humidity_variance.min(consensus_variance);
        }

        Ok(ConsensusSummary {
            accepted_neighbors,
            ignored_neighbors: neighbors.len().saturating_sub(accepted_neighbors),
        })
    }

    pub fn calibrated_temperature_c(&self, raw_temperature_c: f32) -> f32 {
        raw_temperature_c - self.bias_temperature_c
    }

    pub fn calibrated_humidity_percent(&self, raw_humidity_percent: f32) -> f32 {
        raw_humidity_percent - self.bias_humidity_percent
    }

    pub fn calibrated_reading(
        &self,
        raw_temperature_c: f32,
        raw_humidity_percent: f32,
    ) -> CalibratedReading {
        CalibratedReading {
            temperature_c: self.calibrated_temperature_c(raw_temperature_c),
            humidity_percent: self.calibrated_humidity_percent(raw_humidity_percent),
            calibration_confidence: self.calibration_confidence(),
        }
    }

    pub fn calibration_confidence(&self) -> f32 {
        let variance_sum = self.bias_temperature_variance + self.bias_humidity_variance;
        (-variance_sum.max(0.0)).exp().clamp(0.0, 1.0)
    }

    fn is_valid(&self) -> bool {
        self.true_temperature_c.is_finite()
            && self.true_humidity_percent.is_finite()
            && self.bias_temperature_c.is_finite()
            && self.bias_humidity_percent.is_finite()
            && self.bias_temperature_variance.is_finite()
            && self.bias_humidity_variance.is_finite()
            && self.bias_temperature_variance > 0.0
            && self.bias_humidity_variance > 0.0
            && (0.0..=100.0).contains(&self.true_humidity_percent)
    }
}

fn is_eligible_neighbor(neighbor: &BiasEstimate, expected_gradient_version: u32) -> bool {
    neighbor.fresh
        && neighbor.gradient_model_version == expected_gradient_version
        && neighbor.temperature_c.is_finite()
        && neighbor.humidity_percent.is_finite()
        && neighbor.temperature_variance.is_finite()
        && neighbor.humidity_variance.is_finite()
        && neighbor.link_confidence.is_finite()
        && neighbor.temperature_variance > 0.0
        && neighbor.humidity_variance > 0.0
        && (0.0..=1.0).contains(&neighbor.link_confidence)
}
