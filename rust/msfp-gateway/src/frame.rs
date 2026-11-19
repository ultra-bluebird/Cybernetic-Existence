use crate::{GatewayError, IncomingFrame, SessionId, NONCE_BYTES};
use serde::Deserialize;

const MAX_RAW_FRAME_BYTES: usize = 4_096;
const FRAME_SCHEMA_VERSION: &str = "1";

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireFrame {
    schema_version: String,
    session_id: String,
    generation: u64,
    sequence: u64,
    nonce: String,
    purpose: String,
    operation: String,
    data_category: String,
    audience: String,
    payload: String,
}

pub fn decode_strict_json_frame(
    raw: &[u8],
) -> Result<DecodedFrame, GatewayError> {
    if raw.len() > MAX_RAW_FRAME_BYTES {
        return Err(GatewayError::FrameTooLarge);
    }

    if !raw.is_ascii() {
        return Err(GatewayError::InvalidTranscriptText);
    }

    let wire: WireFrame =
        serde_json::from_slice(raw).map_err(|_| GatewayError::InvalidTranscript)?;

    if wire.schema_version != FRAME_SCHEMA_VERSION {
        return Err(GatewayError::InvalidTranscript);
    }

    let session_id = decode_hex_16(&wire.session_id)?;
    let nonce = decode_hex_32(&wire.nonce)?;

    Ok(DecodedFrame {
        purpose: wire.purpose,
        operation: wire.operation,
        data_category: wire.data_category,
        audience: wire.audience,
        payload: wire.payload.into_bytes(),
        session_id: SessionId(session_id),
        generation: wire.generation,
        sequence: wire.sequence,
        nonce,
    })
}

pub struct DecodedFrame {
    pub purpose: String,
    pub operation: String,
    pub data_category: String,
    pub audience: String,
    pub payload: Vec<u8>,
    pub session_id: SessionId,
    pub generation: u64,
    pub sequence: u64,
    pub nonce: [u8; NONCE_BYTES],
}

impl DecodedFrame {
    pub fn as_incoming_frame(&self) -> IncomingFrame<'_> {
        IncomingFrame {
            session_id: self.session_id,
            generation: self.generation,
            sequence: self.sequence,
            nonce: self.nonce,
            operation: &self.operation,
            data_category: &self.data_category,
            audience: &self.audience,
            payload: &self.payload,
        }
    }
}

fn decode_hex_16(value: &str) -> Result<[u8; 16], GatewayError> {
    let bytes = decode_hex(value, 16)?;
    let mut output = [0_u8; 16];
    output.copy_from_slice(&bytes);
    Ok(output)
}

fn decode_hex_32(value: &str) -> Result<[u8; NONCE_BYTES], GatewayError> {
    let bytes = decode_hex(value, NONCE_BYTES)?;
    let mut output = [0_u8; NONCE_BYTES];
    output.copy_from_slice(&bytes);
    Ok(output)
}

fn decode_hex(
    value: &str,
    expected_bytes: usize,
) -> Result<Vec<u8>, GatewayError> {
    if value.len() != expected_bytes * 2 {
        return Err(GatewayError::InvalidTranscript);
    }

    let mut output = Vec::with_capacity(expected_bytes);
    let bytes = value.as_bytes();

    for chunk in bytes.chunks_exact(2) {
        let high = hex_nibble(chunk[0])?;
        let low = hex_nibble(chunk[1])?;
        output.push((high << 4) | low);
    }

    Ok(output)
}

fn hex_nibble(value: u8) -> Result<u8, GatewayError> {
    match value {
        b'0'..=b'9' => Ok(value - b'0'),
        b'a'..=b'f' => Ok(value - b'a' + 10),
        _ => Err(GatewayError::InvalidTranscript),
    }
}
