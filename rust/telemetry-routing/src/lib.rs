#![forbid(unsafe_code)]

use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct ChannelId(pub String);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RouteId(pub String);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DecoderVersion(pub String);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RouteEpoch(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Thresholds {
    pub max_latency_micros: u64,
    pub max_jitter_micros: u64,
    pub max_loss_parts_per_million: u32,
    pub max_queue_parts_per_million: u32,
    pub min_integrity_parts_per_million: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChannelHealth {
    pub latency_micros: u64,
    pub jitter_micros: u64,
    pub loss_parts_per_million: u32,
    pub queue_parts_per_million: u32,
    pub integrity_parts_per_million: u32,
    pub verified: bool,
}

impl ChannelHealth {
    pub fn is_admissible(self, thresholds: Thresholds) -> bool {
        self.verified
            && self.latency_micros <= thresholds.max_latency_micros
            && self.jitter_micros <= thresholds.max_jitter_micros
            && self.loss_parts_per_million <= thresholds.max_loss_parts_per_million
            && self.queue_parts_per_million <= thresholds.max_queue_parts_per_million
            && self.integrity_parts_per_million >= thresholds.min_integrity_parts_per_million
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RouteCandidate {
    pub route_id: RouteId,
    pub decoder_version: DecoderVersion,
    pub ordered_channels: Vec<ChannelId>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RerouteReceipt {
    pub previous_route: Option<RouteId>,
    pub selected_route: RouteId,
    pub graph_epoch: RouteEpoch,
    pub decoder_version: DecoderVersion,
    pub isolated_channels: BTreeSet<ChannelId>,
    pub reason: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RerouteError {
    NoCompatibleVerifiedRoute,
    EmptyRoute(RouteId),
    MissingHealth(ChannelId),
    DuplicateChannel(ChannelId),
}

pub fn select_verified_route(
    previous_route: Option<RouteId>,
    required_decoder: &DecoderVersion,
    candidates: &[RouteCandidate],
    health: &BTreeMap<ChannelId, ChannelHealth>,
    isolated: &BTreeSet<ChannelId>,
    thresholds: Thresholds,
    graph_epoch: RouteEpoch,
    reason: impl Into<String>,
) -> Result<RerouteReceipt, RerouteError> {
    let mut valid_candidates = candidates
        .iter()
        .filter(|candidate| &candidate.decoder_version == required_decoder)
        .filter(|candidate| route_is_usable(candidate, health, isolated, thresholds))
        .collect::<Vec<_>>();

    valid_candidates.sort_by(|left, right| {
        let left_score = route_score(left, health);
        let right_score = route_score(right, health);

        left_score
            .cmp(&right_score)
            .then_with(|| left.route_id.0.cmp(&right.route_id.0))
    });

    let selected = valid_candidates
        .into_iter()
        .next()
        .ok_or(RerouteError::NoCompatibleVerifiedRoute)?;

    Ok(RerouteReceipt {
        previous_route,
        selected_route: selected.route_id.clone(),
        graph_epoch,
        decoder_version: selected.decoder_version.clone(),
        isolated_channels: isolated.clone(),
        reason: reason.into(),
    })
}

fn route_is_usable(
    candidate: &RouteCandidate,
    health: &BTreeMap<ChannelId, ChannelHealth>,
    isolated: &BTreeSet<ChannelId>,
    thresholds: Thresholds,
) -> bool {
    if candidate.ordered_channels.is_empty() {
        return false;
    }

    let mut observed = BTreeSet::new();

    candidate.ordered_channels.iter().all(|channel| {
        observed.insert(channel.clone())
            && !isolated.contains(channel)
            && health
                .get(channel)
                .is_some_and(|state| state.is_admissible(thresholds))
    })
}

fn route_score(
    candidate: &RouteCandidate,
    health: &BTreeMap<ChannelId, ChannelHealth>,
) -> u128 {
    candidate
        .ordered_channels
        .iter()
        .filter_map(|channel| health.get(channel))
        .map(|state| {
            u128::from(state.latency_micros)
                + u128::from(state.jitter_micros) * 4
                + u128::from(state.loss_parts_per_million) * 8
                + u128::from(state.queue_parts_per_million) * 2
                + u128::from(1_000_000_u32.saturating_sub(
                    state.integrity_parts_per_million,
                )) * 8
        })
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn channel(value: &str) -> ChannelId {
        ChannelId(value.to_owned())
    }

    fn route(value: &str) -> RouteId {
        RouteId(value.to_owned())
    }

    fn decoder(value: &str) -> DecoderVersion {
        DecoderVersion(value.to_owned())
    }

    fn healthy() -> ChannelHealth {
        ChannelHealth {
            latency_micros: 500,
            jitter_micros: 30,
            loss_parts_per_million: 10,
            queue_parts_per_million: 100,
            integrity_parts_per_million: 999_900,
            verified: true,
        }
    }

    fn thresholds() -> Thresholds {
        Thresholds {
            max_latency_micros: 2_000,
            max_jitter_micros: 250,
            max_loss_parts_per_million: 1_000,
            max_queue_parts_per_million: 10_000,
            min_integrity_parts_per_million: 990_000,
        }
    }

    #[test]
    fn selects_the_best_verified_non_isolated_compatible_route() {
        let candidates = vec![
            RouteCandidate {
                route_id: route("primary"),
                decoder_version: decoder("spatial-v3"),
                ordered_channels: vec![channel("a"), channel("b")],
            },
            RouteCandidate {
                route_id: route("adjacent-verified"),
                decoder_version: decoder("spatial-v3"),
                ordered_channels: vec![channel("c")],
            },
            RouteCandidate {
                route_id: route("incompatible"),
                decoder_version: decoder("spatial-v4"),
                ordered_channels: vec![channel("d")],
            },
        ];

        let mut health = BTreeMap::new();
        health.insert(channel("a"), healthy());
        health.insert(channel("b"), healthy());
        health.insert(channel("c"), healthy());
        health.insert(channel("d"), healthy());

        let isolated = BTreeSet::from([channel("a")]);

        let receipt = select_verified_route(
            Some(route("primary")),
            &decoder("spatial-v3"),
            &candidates,
            &health,
            &isolated,
            thresholds(),
            RouteEpoch(42),
            "isolation-detected",
        )
        .expect("a verified adjacent path should be selected");

        assert_eq!(receipt.selected_route, route("adjacent-verified"));
        assert_eq!(receipt.graph_epoch, RouteEpoch(42));
        assert_eq!(receipt.decoder_version, decoder("spatial-v3"));
    }

    #[test]
    fn rejects_unverified_paths() {
        let candidates = vec![RouteCandidate {
            route_id: route("unverified"),
            decoder_version: decoder("spatial-v3"),
            ordered_channels: vec![channel("a")],
        }];

        let mut health = BTreeMap::new();
        health.insert(
            channel("a"),
            ChannelHealth {
                verified: false,
                ..healthy()
            },
        );

        let result = select_verified_route(
            None,
            &decoder("spatial-v3"),
            &candidates,
            &health,
            &BTreeSet::new(),
            thresholds(),
            RouteEpoch(1),
            "verification-failed",
        );

        assert_eq!(result, Err(RerouteError::NoCompatibleVerifiedRoute));
    }
}
