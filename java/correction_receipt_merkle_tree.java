package org.augmentedhub.corrections;

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

public final class CorrectionReceiptMerkleTree {
    public enum Direction {
        LEFT,
        RIGHT
    }

    public record ProofStep(Direction siblingDirection, byte[] siblingHash) {
        public ProofStep {
            Objects.requireNonNull(siblingDirection, "siblingDirection");
            siblingHash = copyAndValidateHash(siblingHash);
        }

        @Override
        public byte[] siblingHash() {
            return siblingHash.clone();
        }
    }

    public record InclusionProof(
            long leafIndex,
            long treeSize,
            List<ProofStep> steps
    ) {
        public InclusionProof {
            if (leafIndex < 0 || treeSize <= 0 || leafIndex >= treeSize) {
                throw new IllegalArgumentException("Leaf index and tree size are invalid.");
            }
            steps = List.copyOf(steps);
        }
    }

    private CorrectionReceiptMerkleTree() {
    }

    public static byte[] receiptLeafHash(byte[] canonicalReceipt) {
        Objects.requireNonNull(canonicalReceipt, "canonicalReceipt");
        if (canonicalReceipt.length == 0) {
            throw new IllegalArgumentException("Canonical receipt must not be empty.");
        }

        return sha256(prefixed((byte) 0x00, canonicalReceipt));
    }

    public static byte[] parentHash(byte[] left, byte[] right) {
        return sha256(prefixed((byte) 0x01, copyAndValidateHash(left), copyAndValidateHash(right)));
    }

    public static boolean verifyInclusion(
            byte[] canonicalReceipt,
            InclusionProof proof,
            byte[] expectedRoot) {

        Objects.requireNonNull(canonicalReceipt, "canonicalReceipt");
        Objects.requireNonNull(proof, "proof");
        expectedRoot = copyAndValidateHash(expectedRoot);

        byte[] computed = receiptLeafHash(canonicalReceipt);

        for (ProofStep step : proof.steps()) {
            computed = step.siblingDirection() == Direction.LEFT
                    ? parentHash(step.siblingHash(), computed)
                    : parentHash(computed, step.siblingHash());
        }

        return MessageDigest.isEqual(computed, expectedRoot);
    }

    public static byte[] rootForLeaves(List<byte[]> canonicalReceipts) {
        Objects.requireNonNull(canonicalReceipts, "canonicalReceipts");

        if (canonicalReceipts.isEmpty()) {
            throw new IllegalArgumentException("At least one canonical receipt is required.");
        }

        List<byte[]> level = new ArrayList<>(canonicalReceipts.size());

        for (byte[] receipt : canonicalReceipts) {
            level.add(receiptLeafHash(receipt));
        }

        while (level.size() > 1) {
            List<byte[]> next = new ArrayList<>((level.size() + 1) / 2);

            for (int index = 0; index < level.size(); index += 2) {
                byte[] left = level.get(index);
                byte[] right = index + 1 < level.size() ? level.get(index + 1) : left;
                next.add(parentHash(left, right));
            }

            level = next;
        }

        return level.getFirst().clone();
    }

    public static byte[] canonicalReceipt(
            byte[] receiptReference,
            byte[] caseScopedNonce,
            long issuedAtEpochSeconds,
            byte[] stateCommitment) {

        Objects.requireNonNull(receiptReference, "receiptReference");
        Objects.requireNonNull(caseScopedNonce, "caseScopedNonce");
        Objects.requireNonNull(stateCommitment, "stateCommitment");

        if (receiptReference.length == 0 || caseScopedNonce.length == 0
                || stateCommitment.length == 0 || issuedAtEpochSeconds < 0) {
            throw new IllegalArgumentException("Receipt fields are invalid.");
        }

        ByteBuffer buffer = ByteBuffer.allocate(
                Integer.BYTES + receiptReference.length
                        + Integer.BYTES + caseScopedNonce.length
                        + Long.BYTES
                        + Integer.BYTES + stateCommitment.length);

        putLengthPrefixed(buffer, receiptReference);
        putLengthPrefixed(buffer, caseScopedNonce);
        buffer.putLong(issuedAtEpochSeconds);
        putLengthPrefixed(buffer, stateCommitment);

        return buffer.array();
    }

    private static void putLengthPrefixed(ByteBuffer buffer, byte[] value) {
        buffer.putInt(value.length);
        buffer.put(value);
    }

    private static byte[] prefixed(byte prefix, byte[]... values) {
        int totalLength = 1;

        for (byte[] value : values) {
            totalLength += value.length;
        }

        ByteBuffer buffer = ByteBuffer.allocate(totalLength);
        buffer.put(prefix);

        for (byte[] value : values) {
            buffer.put(value);
        }

        return buffer.array();
    }

    private static byte[] copyAndValidateHash(byte[] value) {
        Objects.requireNonNull(value, "hash");

        if (value.length != 32) {
            throw new IllegalArgumentException("SHA-256 hashes must be exactly 32 bytes.");
        }

        return Arrays.copyOf(value, value.length);
    }

    private static byte[] sha256(byte[] value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable.", exception);
        }
    }
}
