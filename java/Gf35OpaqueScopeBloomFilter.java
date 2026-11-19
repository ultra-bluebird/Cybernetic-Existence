package org.augmentedhub.gf35;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.BitSet;
import java.util.Objects;

public final class Gf35OpaqueScopeBloomFilter {
    private final BitSet bits;
    private final int bitCount;
    private final int hashCount;

    public Gf35OpaqueScopeBloomFilter(long expectedEntries, double falsePositiveRate) {
        if (expectedEntries <= 0) {
            throw new IllegalArgumentException("expectedEntries must be positive");
        }
        if (!Double.isFinite(falsePositiveRate)
                || falsePositiveRate <= 0.0
                || falsePositiveRate >= 1.0) {
            throw new IllegalArgumentException("falsePositiveRate must be in (0, 1)");
        }

        final double calculatedBits =
                -expectedEntries * Math.log(falsePositiveRate) / Math.pow(Math.log(2.0), 2.0);

        if (calculatedBits > Integer.MAX_VALUE) {
            throw new IllegalArgumentException("requested Bloom filter exceeds implementation capacity");
        }

        this.bitCount = Math.max(8, (int) Math.ceil(calculatedBits));
        this.hashCount = Math.max(
                1,
                (int) Math.round(((double) bitCount / expectedEntries) * Math.log(2.0)));
        this.bits = new BitSet(bitCount);
    }

    public synchronized void add(String opaqueScopeId) {
        forEachIndex(opaqueScopeId, bits::set);
    }

    public synchronized boolean mightContain(String opaqueScopeId) {
        final boolean[] result = {true};
        forEachIndex(opaqueScopeId, index -> {
            if (!bits.get(index)) {
                result[0] = false;
            }
        });
        return result[0];
    }

    public int bitCount() {
        return bitCount;
    }

    public int hashCount() {
        return hashCount;
    }

    public double estimatedFalsePositiveRate(long insertedEntries) {
        if (insertedEntries < 0) {
            throw new IllegalArgumentException("insertedEntries must be non-negative");
        }
        return Math.pow(
                1.0 - Math.exp(-((double) hashCount * insertedEntries) / bitCount),
                hashCount);
    }

    private void forEachIndex(String opaqueScopeId, IndexConsumer consumer) {
        Objects.requireNonNull(opaqueScopeId, "opaqueScopeId");
        if (opaqueScopeId.isBlank()) {
            throw new IllegalArgumentException("opaqueScopeId must not be blank");
        }

        final byte[] input = opaqueScopeId.getBytes(StandardCharsets.UTF_8);
        final byte[] digest = sha256(input);
        final long h1 = ByteBuffer.wrap(digest, 0, Long.BYTES).getLong();
        final long h2 = ByteBuffer.wrap(digest, Long.BYTES, Long.BYTES).getLong();

        for (int sequence = 0; sequence < hashCount; sequence++) {
            final long combined = h1 + ((long) sequence * h2);
            final int index = Math.floorMod(combined, bitCount);
            consumer.accept(index);
        }
    }

    private static byte[] sha256(byte[] input) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(input);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    @FunctionalInterface
    private interface IndexConsumer {
        void accept(int index);
    }
}
