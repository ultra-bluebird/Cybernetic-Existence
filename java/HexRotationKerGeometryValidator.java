package org.augmentedhub.cyboquatic;

import java.util.List;

public final class HexRotationKerGeometryValidator {
    public record Axial(long q, long r) {
    }

    public record Triad(double k, double e, double r) {
    }

    public record Validation(boolean accepted, String reason) {
    }

    private static final Axial[] AXIAL_NEIGHBOR_DELTAS = {
        new Axial(1L, 0L),
        new Axial(1L, -1L),
        new Axial(0L, -1L),
        new Axial(-1L, 0L),
        new Axial(-1L, 1L),
        new Axial(0L, 1L)
    };

    private HexRotationKerGeometryValidator() {
    }

    public static Validation validateAxialNeighbor(
        final Axial source,
        final Axial neighbor,
        final int edgeIndex
    ) {
        if (source == null || neighbor == null) {
            return new Validation(false, "axial coordinates must not be null");
        }

        if (edgeIndex < 0 || edgeIndex >= AXIAL_NEIGHBOR_DELTAS.length) {
            return new Validation(false, "edge index must be in the closed interval [0, 5]");
        }

        final Axial delta = AXIAL_NEIGHBOR_DELTAS[edgeIndex];
        final Axial expected = new Axial(source.q() + delta.q(), source.r() + delta.r());

        if (!expected.equals(neighbor)) {
            return new Validation(
                false,
                "neighbor does not match the asserted axial hex direction"
            );
        }

        return new Validation(
            true,
            "topology is invariant under any independent planar rotation of the rendered grid"
        );
    }

    public static Validation validateTriadDomain(final Triad candidate) {
        if (candidate == null) {
            return new Validation(false, "KER triad must not be null");
        }

        if (!unitInterval(candidate.k())
            || !unitInterval(candidate.e())
            || !unitInterval(candidate.r())) {
            return new Validation(
                false,
                "each KER coordinate must be finite and within the closed interval [0, 1]"
            );
        }

        return new Validation(true, "KER triad satisfies coordinate bounds");
    }

    public static Validation validateConvexWitness(
        final Triad candidate,
        final List<Triad> vertices,
        final List<Double> weights,
        final double tolerance
    ) {
        final Validation domain = validateTriadDomain(candidate);
        if (!domain.accepted()) {
            return domain;
        }

        if (vertices == null || weights == null
            || vertices.isEmpty()
            || vertices.size() != weights.size()
            || vertices.size() > 4) {
            return new Validation(
                false,
                "a three-dimensional convex witness requires one to four matched vertices and weights"
            );
        }

        if (!Double.isFinite(tolerance) || tolerance < 0.0d || tolerance > 0.001d) {
            return new Validation(
                false,
                "tolerance must be finite, non-negative, and no greater than 0.001"
            );
        }

        double weightSum = 0.0d;
        double k = 0.0d;
        double e = 0.0d;
        double r = 0.0d;

        for (int index = 0; index < vertices.size(); index++) {
            final Triad vertex = vertices.get(index);
            final Double weight = weights.get(index);

            final Validation vertexDomain = validateTriadDomain(vertex);
            if (!vertexDomain.accepted()) {
                return new Validation(false, "hull vertex violates KER coordinate bounds");
            }

            if (weight == null || !Double.isFinite(weight) || weight < 0.0d || weight > 1.0d) {
                return new Validation(false, "convex weights must be finite values in [0, 1]");
            }

            weightSum += weight;
            k += weight * vertex.k();
            e += weight * vertex.e();
            r += weight * vertex.r();
        }

        if (Math.abs(weightSum - 1.0d) > tolerance) {
            return new Validation(false, "convex weights must sum to one within tolerance");
        }

        if (Math.abs(k - candidate.k()) > tolerance
            || Math.abs(e - candidate.e()) > tolerance
            || Math.abs(r - candidate.r()) > tolerance) {
            return new Validation(
                false,
                "candidate is not reconstructed by the declared convex-hull witness"
            );
        }

        return new Validation(
            true,
            "candidate lies within the declared same-semantics KER convex hull"
        );
    }

    private static boolean unitInterval(final double value) {
        return Double.isFinite(value) && value >= 0.0d && value <= 1.0d;
    }
}
