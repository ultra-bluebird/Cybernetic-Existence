
use aln_bind_types::tilespace_fp_ic::{SimSwarmConfig, FpicStatus, TileSpaceBinding};

alnbind! shard tilespace.fp_ic.binding.v1

record TileBinding
  tile_id String,
  aln_shard_id String,
  jurisdiction_particle String,

record TileSpaceBinding
  host_did Did,
  bostrom_address BostromAddr,
  migration_authority AlnMigrationAuthority,
  tiles VecTileBinding,

record FpicConsentBundle
  host_did Did,
  bostrom_address BostromAddr,
  migration_authority AlnMigrationAuthority,
  tilespace_id String,
  status FpicStatus,           
  evidence_bundle_id EvidenceBundleId,

record SimSwarmConfig
  sim_id SimId,
  tilespace TileSpaceBinding,
  fpic FpicConsentBundle,

    #[derive(Clone, Debug)]
pub struct TileBinding {
    pub tile_id: String,
    pub aln_shard_id: String,
    pub jurisdiction_particle: String,
}

#[derive(Clone, Debug)]
pub struct TileSpaceBinding {
    pub host_did: Did,
    pub bostrom_address: BostromAddr,
    pub migration_authority: AlnMigrationAuthority,
    pub tiles: Vec<TileBinding>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FpicStatus {
    Granted,
    Withheld,
    Denied,
}

#[derive(Clone, Debug)]
pub struct FpicConsentBundle {
    pub host_did: Did,
    pub bostrom_address: BostromAddr,
    pub migration_authority: AlnMigrationAuthority,
    pub tilespace_id: String,
    pub status: FpicStatus,
    pub evidence_bundle_id: EvidenceBundleId,
}

#[derive(Clone, Debug)]
pub struct SimSwarmConfig {
    pub sim_id: SimId,
    pub tilespace: TileSpaceBinding,
    pub fpic: FpicConsentBundle,
}

pub trait AlnLoad: Sized {
    fn from_aln_str(s: &str) -> Result<Self, String>;
}

impl AlnLoad for SimSwarmConfig {
    fn from_aln_str(s: &str) -> Result<Self, String> {
        // Implementation should parse tilespace.fp_ic.binding.v1 .aln text,
        // enforce ALN.MIGRATION.CYBERCOREAUTHORITY.v1 on migration_authority,
        // enforce non-empty host_did and bostrom_address,
        // and map FPIC status strings to FpicStatus.
        unimplemented!()
    }
}
