#![forbid(unsafe_code)]

use serde::Serialize;
use thiserror::Error;

pub const MAX_QUARANTINE_BYTES: usize = 16 * 1024;
pub const MAX_NESTING: usize = 8;
pub const MAX_QUOTE_RUN: usize = 4 * 1024;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum InspectError {
    #[error("input is empty")]
    Empty,
    #[error("input exceeds quarantine limit")]
    Oversized,
    #[error("input has excessive structural nesting")]
    ExcessiveNesting,
    #[error("input contains an overlong unterminated string")]
    OverlongString,
    #[error("input has unmatched closing delimiter")]
    UnmatchedClosingDelimiter,
    #[error("input ends with an incomplete structure")]
    IncompleteStructure,
}

#[derive(Debug, Serialize, PartialEq, Eq)]
pub struct Inspection {
    pub byte_len: usize,
    pub max_nesting_seen: usize,
    pub string_count: usize,
    pub object_count: usize,
    pub array_count: usize,
    pub execution_attempted: bool,
}

pub fn inspect_quarantined(input: &[u8]) -> Result<Inspection, InspectError> {
    if input.is_empty() {
        return Err(InspectError::Empty);
    }
    if input.len() > MAX_QUARANTINE_BYTES {
        return Err(InspectError::Oversized);
    }

    let mut depth = 0usize;
    let mut max_depth = 0usize;
    let mut strings = 0usize;
    let mut objects = 0usize;
    let mut arrays = 0usize;
    let mut in_string = false;
    let mut escaped = false;
    let mut string_run = 0usize;

    for &byte in input {
        if in_string {
            string_run += 1;
            if string_run > MAX_QUOTE_RUN {
                return Err(InspectError::OverlongString);
            }

            if escaped {
                escaped = false;
                continue;
            }

            match byte {
                b'\\' => escaped = true,
                b'"' => {
                    in_string = false;
                    strings += 1;
                    string_run = 0;
                }
                _ => {}
            }
            continue;
        }

        match byte {
            b'"' => {
                in_string = true;
                string_run = 0;
            }
            b'{' => {
                depth += 1;
                objects += 1;
                max_depth = max_depth.max(depth);
                if depth > MAX_NESTING {
                    return Err(InspectError::ExcessiveNesting);
                }
            }
            b'[' => {
                depth += 1;
                arrays += 1;
                max_depth = max_depth.max(depth);
                if depth > MAX_NESTING {
                    return Err(InspectError::ExcessiveNesting);
                }
            }
            b'}' | b']' => {
                depth = depth.checked_sub(1).ok_or(InspectError::UnmatchedClosingDelimiter)?;
            }
            _ => {}
        }
    }

    if in_string || depth != 0 {
        return Err(InspectError::IncompleteStructure);
    }

    Ok(Inspection {
        byte_len: input.len(),
        max_nesting_seen: max_depth,
        string_count: strings,
        object_count: objects,
        array_count: arrays,
        execution_attempted: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn does_not_execute_input() {
        let result = inspect_quarantined(br#"{"payload":"$(never-execute)"}"#).unwrap();
        assert!(!result.execution_attempted);
    }

    #[test]
    fn rejects_deep_nesting() {
        let nested = format!("{}0{}", "[".repeat(MAX_NESTING + 1), "]".repeat(MAX_NESTING + 1));
        assert_eq!(
            inspect_quarantined(nested.as_bytes()),
            Err(InspectError::ExcessiveNesting)
        );
    }

    #[test]
    fn rejects_oversized_quarantine_input() {
        let input = vec![b'x'; MAX_QUARANTINE_BYTES + 1];
        assert_eq!(inspect_quarantined(&input), Err(InspectError::Oversized));
    }
}
