use crate::bounds::{FiniteF64, NonNegativeF64, UnitInterval};
use crate::error::{PopmathError, PopmathResult};

/// Explicit deterministic seed for reproducible stochastic calculations.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RandomSeed(u64);

impl RandomSeed {
    /// Creates an explicit seed.
    #[must_use]
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    /// Returns the seed value.
    #[must_use]
    pub const fn get(self) -> u64 {
        self.0
    }
}

/// Small deterministic pseudo-random generator for reproducible scenario sampling.
///
/// This generator is intended for simulation reproducibility, not cryptography.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeterministicRng {
    state: u64,
}

impl DeterministicRng {
    /// Initializes a deterministic generator from an explicit seed.
    #[must_use]
    pub const fn from_seed(seed: RandomSeed) -> Self {
        Self { state: seed.get() }
    }

    /// Produces the next pseudo-random unsigned integer.
    #[must_use]
    pub fn next_u64(&mut self) -> u64 {
        self.state = self
            .state
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        self.state
    }

    /// Produces a deterministic value in the inclusive lower and exclusive upper unit interval.
    #[must_use]
    pub fn next_unit_interval(&mut self) -> f64 {
        let high_bits = self.next_u64() >> 11;
        high_bits as f64 / ((1_u64 << 53) as f64)
    }
}

/// A bounded triangular uncertainty distribution.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TriangularDistribution {
    /// Lower supported value.
    pub minimum: FiniteF64,
    /// Most likely value.
    pub mode: FiniteF64,
    /// Upper supported value.
    pub maximum: FiniteF64,
}

impl TriangularDistribution {
    /// Validates distribution ordering.
    pub fn validate(&self) -> PopmathResult<()> {
        if self.minimum.get() > self.mode.get() || self.mode.get() > self.maximum.get() {
            return Err(PopmathError::InvalidInterval {
                field: "triangular_distribution",
            });
        }

        Ok(())
    }

    /// Samples a deterministic value from the distribution.
    pub fn sample(&self, rng: &mut DeterministicRng) -> PopmathResult<FiniteF64> {
        self.validate()?;

        let minimum = self.minimum.get();
        let mode = self.mode.get();
        let maximum = self.maximum.get();

        if minimum == maximum {
            return FiniteF64::new(minimum, "triangular_sample");
        }

        let draw = rng.next_unit_interval();
        let split = (mode - minimum) / (maximum - minimum);

        let sampled = if draw <= split {
            minimum + ((draw * (maximum - minimum) * (mode - minimum)).sqrt())
        } else {
            maximum - (((1.0 - draw) * (maximum - minimum) * (maximum - mode)).sqrt())
        };

        FiniteF64::new(sampled, "triangular_sample")
    }
}

/// Input for seeded Monte Carlo summarization.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MonteCarloInput {
    /// Distribution to sample.
    pub distribution: TriangularDistribution,
    /// Explicit deterministic seed.
    pub seed: RandomSeed,
    /// Number of samples.
    pub sample_count: u32,
    /// Lower percentile to report.
    pub lower_percentile: UnitInterval,
    /// Upper percentile to report.
    pub upper_percentile: UnitInterval,
}

impl MonteCarloInput {
    /// Validates a Monte Carlo request.
    pub fn validate(&self) -> PopmathResult<()> {
        self.distribution.validate()?;

        if self.sample_count == 0 {
            return Err(PopmathError::ZeroNotAllowed {
                field: "sample_count",
            });
        }
        if self.lower_percentile.get() > self.upper_percentile.get() {
            return Err(PopmathError::InvalidInterval {
                field: "monte_carlo_percentiles",
            });
        }

        Ok(())
    }
}

/// Result of deterministic seeded Monte Carlo summarization.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MonteCarloResult {
    /// Explicit input seed.
    pub seed: RandomSeed,
    /// Number of generated samples.
    pub sample_count: u32,
    /// Arithmetic mean of samples.
    pub mean: FiniteF64,
    /// Lower requested percentile.
    pub lower_percentile_value: FiniteF64,
    /// Upper requested percentile.
    pub upper_percentile_value: FiniteF64,
    /// Minimum sampled value.
    pub minimum: FiniteF64,
    /// Maximum sampled value.
    pub maximum: FiniteF64,
}

/// Runs a deterministic Monte Carlo summary with explicit seed and percentiles.
pub fn run_monte_carlo(input: MonteCarloInput) -> PopmathResult<MonteCarloResult> {
    input.validate()?;

    let mut rng = DeterministicRng::from_seed(input.seed);
    let mut samples = Vec::with_capacity(input.sample_count as usize);
    let mut total = 0.0;

    for _ in 0..input.sample_count {
        let sample = input.distribution.sample(&mut rng)?;
        total += sample.get();
        samples.push(sample.get());
    }

    samples.sort_by(f64::total_cmp);

    let lower_index =
        percentile_index(input.lower_percentile, input.sample_count)?;
    let upper_index =
        percentile_index(input.upper_percentile, input.sample_count)?;

    let mean = total / input.sample_count as f64;
    let minimum = *samples.first().ok_or(PopmathError::NumericalInstability {
        component: "monte_carlo_minimum",
    })?;
    let maximum = *samples.last().ok_or(PopmathError::NumericalInstability {
        component: "monte_carlo_maximum",
    })?;

    Ok(MonteCarloResult {
        seed: input.seed,
        sample_count: input.sample_count,
        mean: FiniteF64::new(mean, "monte_carlo_mean")?,
        lower_percentile_value: FiniteF64::new(
            samples[lower_index],
            "monte_carlo_lower_percentile",
        )?,
        upper_percentile_value: FiniteF64::new(
            samples[upper_index],
            "monte_carlo_upper_percentile",
        )?,
        minimum: FiniteF64::new(minimum, "monte_carlo_minimum")?,
        maximum: FiniteF64::new(maximum, "monte_carlo_maximum")?,
    })
}

fn percentile_index(percentile: UnitInterval, sample_count: u32) -> PopmathResult<usize> {
    if sample_count == 0 {
        return Err(PopmathError::ZeroNotAllowed {
            field: "sample_count",
        });
    }

    let scaled = percentile.get() * (sample_count.saturating_sub(1)) as f64;
    let index = scaled.round();

    if index > usize::MAX as f64 {
        return Err(PopmathError::NumericalInstability {
            component: "percentile_index",
        });
    }

    Ok(index as usize)
}

/// Input for a deterministic sensitivity range.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SensitivityInput {
    /// Baseline input value.
    pub baseline: FiniteF64,
    /// Lower tested value.
    pub lower: FiniteF64,
    /// Upper tested value.
    pub upper: FiniteF64,
}

/// Result of an affine sensitivity transformation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SensitivityResult {
    /// Baseline output value.
    pub baseline_output: FiniteF64,
    /// Output under lower tested value.
    pub lower_output: FiniteF64,
    /// Output under upper tested value.
    pub upper_output: FiniteF64,
    /// Absolute output span across tested input bounds.
    pub output_span: NonNegativeF64,
}

/// Evaluates an affine output \(a x + b\) across a declared input range.
pub fn calculate_affine_sensitivity(
    input: SensitivityInput,
    coefficient: FiniteF64,
    intercept: FiniteF64,
) -> PopmathResult<SensitivityResult> {
    if input.lower.get() > input.baseline.get() || input.baseline.get() > input.upper.get() {
        return Err(PopmathError::InvalidInterval {
            field: "sensitivity_input",
        });
    }

    let evaluate = |value: f64| coefficient.get() * value + intercept.get();
    let baseline_output = evaluate(input.baseline.get());
    let lower_output = evaluate(input.lower.get());
    let upper_output = evaluate(input.upper.get());

    if !baseline_output.is_finite() || !lower_output.is_finite() || !upper_output.is_finite() {
        return Err(PopmathError::NumericalInstability {
            component: "affine_sensitivity",
        });
    }

    let output_span = (upper_output - lower_output).abs();

    Ok(SensitivityResult {
        baseline_output: FiniteF64::new(baseline_output, "baseline_output")?,
        lower_output: FiniteF64::new(lower_output, "lower_output")?,
        upper_output: FiniteF64::new(upper_output, "upper_output")?,
        output_span: NonNegativeF64::new(output_span, "output_span")?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn monte_carlo_is_reproducible_for_the_same_seed() {
        let input = MonteCarloInput {
            distribution: TriangularDistribution {
                minimum: FiniteF64::new(10.0, "minimum").expect("valid"),
                mode: FiniteF64::new(15.0, "mode").expect("valid"),
                maximum: FiniteF64::new(20.0, "maximum").expect("valid"),
            },
            seed: RandomSeed::new(42),
            sample_count: 1_000,
            lower_percentile: UnitInterval::new(0.1, "lower_percentile").expect("valid"),
            upper_percentile: UnitInterval::new(0.9, "upper_percentile").expect("valid"),
        };

        let first = run_monte_carlo(input).expect("valid simulation");
        let second = run_monte_carlo(input).expect("valid simulation");

        assert_eq!(first, second);
        assert!(first.minimum.get() >= 10.0);
        assert!(first.maximum.get() <= 20.0);
    }

    #[test]
    fn affine_sensitivity_reports_output_span() {
        let result = calculate_affine_sensitivity(
            SensitivityInput {
                baseline: FiniteF64::new(10.0, "baseline").expect("valid"),
                lower: FiniteF64::new(8.0, "lower").expect("valid"),
                upper: FiniteF64::new(12.0, "upper").expect("valid"),
            },
            FiniteF64::new(2.0, "coefficient").expect("valid"),
            FiniteF64::new(1.0, "intercept").expect("valid"),
        )
        .expect("valid sensitivity");

        assert_eq!(result.baseline_output.get(), 21.0);
        assert_eq!(result.output_span.get(), 8.0);
    }
}
