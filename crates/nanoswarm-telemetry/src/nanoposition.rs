// Filename: mk-bluebird/nanorobotics/crates/nanoswarm-telemetry/src/nanoposition.rs
// Destination: mk-bluebird/nanorobotics

#![forbid(unsafe_code)]

#[repr(C, align(32))]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct NanoPosition3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
    pub ts: u32,
    pub flags: u32,
}

impl NanoPosition3 {
    pub fn to_bytes_le(self) -> [u8; 32] {
        let mut buf = [0u8; 32];

        let x_bytes = self.x.to_le_bytes();
        let y_bytes = self.y.to_le_bytes();
        let z_bytes = self.z.to_le_bytes();
        let ts_bytes = self.ts.to_le_bytes();
        let flags_bytes = self.flags.to_le_bytes();

        buf[0..8].copy_from_slice(&x_bytes);
        buf[8..16].copy_from_slice(&y_bytes);
        buf[16..24].copy_from_slice(&z_bytes);
        buf[24..28].copy_from_slice(&ts_bytes);
        buf[28..32].copy_from_slice(&flags_bytes);

        buf
    }

    pub fn from_bytes_le(buf: [u8; 32]) -> Self {
        let x = f64::from_le_bytes(buf[0..8].try_into().unwrap());
        let y = f64::from_le_bytes(buf[8..16].try_into().unwrap());
        let z = f64::from_le_bytes(buf[16..24].try_into().unwrap());
        let ts = u32::from_le_bytes(buf[24..28].try_into().unwrap());
        let flags = u32::from_le_bytes(buf[28..32].try_into().unwrap());

        NanoPosition3 { x, y, z, ts, flags }
    }
}
