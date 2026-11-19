use std::collections::BTreeSet;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PublicPoint {
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReportFingerprint {
    pub category: String,
    pub coarse_cell: String,
    pub observed_day: i32,
    pub normalized_tokens: BTreeSet<String>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DuplicateWeights {
    pub location: f64,
    pub text: f64,
    pub category: f64,
    pub time: f64,
}

impl DuplicateWeights {
    pub fn validate(self) -> Result<(), &'static str> {
        let values = [self.location, self.text, self.category, self.time];

        if values.iter().any(|value| *value < 0.0) {
            return Err("duplicate weights must be non-negative");
        }

        let sum: f64 = values.iter().sum();

        if (sum - 1.0).abs() > 1e-9 {
            return Err("duplicate weights must sum to 1.0");
        }

        Ok(())
    }
}

pub fn normalized_text_tokens(text: &str) -> BTreeSet<String> {
    text.split_whitespace()
        .map(normalize_token)
        .filter(|token| token.len() >= 3)
        .filter(|token| !contains_long_numeric_sequence(token))
        .filter(|token| !looks_like_contact_token(token))
        .collect()
}

pub fn jaccard_similarity(
    left: &BTreeSet<String>,
    right: &BTreeSet<String>,
) -> f64 {
    if left.is_empty() && right.is_empty() {
        return 1.0;
    }

    let intersection = left.intersection(right).count();
    let union = left.union(right).count();

    intersection as f64 / union as f64
}

pub fn duplicate_score(
    candidate: &ReportFingerprint,
    existing: &ReportFingerprint,
    weights: DuplicateWeights,
    maximum_day_difference: i32,
) -> Result<f64, &'static str> {
    weights.validate()?;

    if maximum_day_difference <= 0 {
        return Err("maximum_day_difference must be positive");
    }

    let location_score = f64::from(candidate.coarse_cell == existing.coarse_cell);
    let category_score = f64::from(candidate.category == existing.category);
    let text_score = jaccard_similarity(
        &candidate.normalized_tokens,
        &existing.normalized_tokens,
    );

    let day_difference = (candidate.observed_day - existing.observed_day).abs();
    let time_score = if day_difference >= maximum_day_difference {
        0.0
    } else {
        1.0 - day_difference as f64 / maximum_day_difference as f64
    };

    Ok(
        weights.location * location_score
            + weights.text * text_score
            + weights.category * category_score
            + weights.time * time_score,
    )
}

fn normalize_token(token: &str) -> String {
    token
        .chars()
        .filter(|character| character.is_alphanumeric())
        .flat_map(char::to_lowercase)
        .collect()
}

fn contains_long_numeric_sequence(token: &str) -> bool {
    token.chars().filter(char::is_ascii_digit).count() >= 6
}

fn looks_like_contact_token(token: &str) -> bool {
    token.contains('@') || token.starts_with("http") || token.starts_with("www")
}

#[cfg(test)]
mod tests {
    use super::{
        duplicate_score, jaccard_similarity, normalized_text_tokens,
        DuplicateWeights, ReportFingerprint,
    };

    fn weights() -> DuplicateWeights {
        DuplicateWeights {
            location: 0.40,
            text: 0.30,
            category: 0.20,
            time: 0.10,
        }
    }

    #[test]
    fn normalized_tokens_remove_possible_contact_content() {
        let tokens = normalized_text_tokens(
            "Large pothole near corner contact person@example.org 5551234567",
        );

        assert!(tokens.contains("pothole"));
        assert!(!tokens.contains("personexampleorg"));
        assert!(!tokens.contains("5551234567"));
    }

    #[test]
    fn jaccard_similarity_matches_shared_tokens() {
        let left = normalized_text_tokens("broken curb ramp at public crossing");
        let right = normalized_text_tokens("public crossing has broken curb ramp");

        assert!(jaccard_similarity(&left, &right) > 0.5);
    }

    #[test]
    fn matching_issue_has_high_duplicate_score() {
        let candidate = ReportFingerprint {
            category: "curb-ramp".to_owned(),
            coarse_cell: "public-cell-a".to_owned(),
            observed_day: 100,
            normalized_tokens: normalized_text_tokens(
                "broken curb ramp at public crossing",
            ),
        };

        let existing = ReportFingerprint {
            category: "curb-ramp".to_owned(),
            coarse_cell: "public-cell-a".to_owned(),
            observed_day: 101,
            normalized_tokens: normalized_text_tokens(
                "public crossing has broken curb ramp",
            ),
        };

        let score = duplicate_score(&candidate, &existing, weights(), 7)
            .expect("valid duplicate score");

        assert!(score > 0.8);
    }

    #[test]
    fn different_category_and_cell_has_low_duplicate_score() {
        let candidate = ReportFingerprint {
            category: "streetlight".to_owned(),
            coarse_cell: "public-cell-a".to_owned(),
            observed_day: 100,
            normalized_tokens: normalized_text_tokens("streetlight is not working"),
        };

        let existing = ReportFingerprint {
            category: "pothole".to_owned(),
            coarse_cell: "public-cell-b".to_owned(),
            observed_day: 100,
            normalized_tokens: normalized_text_tokens("large road surface pothole"),
        };

        let score = duplicate_score(&candidate, &existing, weights(), 7)
            .expect("valid duplicate score");

        assert!(score < 0.2);
    }
}
