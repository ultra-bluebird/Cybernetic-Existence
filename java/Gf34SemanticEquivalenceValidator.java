package org.augmentedhub.gf34;

import java.text.Normalizer;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class Gf34SemanticEquivalenceValidator {
    public enum Decision {
        SEMANTICALLY_EQUIVALENT,
        LANGUAGE_REVIEW_REQUIRED,
        INVALID_INPUT
    }

    public interface EmbeddingProvider {
        double[] embed(String bcp47Tag, String text);
    }

    public record Assessment(
            Decision decision,
            double similarity,
            boolean criticalText,
            boolean protectedContentAligned,
            String reason
    ) {}

    private static final Pattern NUMBER_OR_DATE =
            Pattern.compile("\\b\\d+(?:[.,]\\d+)?(?:[-/:.]\\d+){0,2}\\b");

    private static final Pattern URL =
            Pattern.compile("https?://[^\\s<>()]+", Pattern.CASE_INSENSITIVE);

    private static final Set<String> NEGATION_TOKENS =
            Set.of("no", "not", "never", "without", "cannot", "mustn't", "don't");

    private final EmbeddingProvider embeddings;
    private final double threshold;

    public Gf34SemanticEquivalenceValidator(EmbeddingProvider embeddings, double threshold) {
        this.embeddings = Objects.requireNonNull(embeddings, "embeddings");
        if (!Double.isFinite(threshold) || threshold <= 0.0 || threshold > 1.0) {
            throw new IllegalArgumentException("threshold must be in (0, 1]");
        }
        this.threshold = threshold;
    }

    public Assessment assess(
            String sourceTag,
            String targetTag,
            String sourceText,
            String targetText,
            boolean criticalText) {

        if (!validTag(sourceTag) || !validTag(targetTag)
                || blank(sourceText) || blank(targetText)) {
            return new Assessment(
                    Decision.INVALID_INPUT,
                    Double.NaN,
                    criticalText,
                    false,
                    "Language tags and texts must be present and well formed.");
        }

        final boolean protectedAligned =
                extract(NUMBER_OR_DATE, sourceText).equals(extract(NUMBER_OR_DATE, targetText))
                && extract(URL, sourceText).equals(extract(URL, targetText))
                && negationParity(sourceText, targetText);

        if (!protectedAligned) {
            return new Assessment(
                    Decision.LANGUAGE_REVIEW_REQUIRED,
                    Double.NaN,
                    criticalText,
                    false,
                    "Protected values, links, or negation markers are not aligned.");
        }

        final double similarity = cosine(
                embeddings.embed(sourceTag, sourceText),
                embeddings.embed(targetTag, targetText));

        if (!Double.isFinite(similarity) || similarity < threshold || criticalText) {
            final String reason = criticalText
                    ? "Critical correction-path content requires accessible human review."
                    : "Embedding similarity is below the configured threshold or unavailable.";
            return new Assessment(
                    Decision.LANGUAGE_REVIEW_REQUIRED,
                    similarity,
                    criticalText,
                    true,
                    reason);
        }

        return new Assessment(
                Decision.SEMANTICALLY_EQUIVALENT,
                similarity,
                false,
                true,
                "Automated triage passed; retain a correction and appeal path.");
    }

    private static boolean validTag(String tag) {
        return tag != null
                && tag.matches("^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$");
    }

    private static boolean blank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private static Set<String> extract(Pattern pattern, String value) {
        final java.util.Set<String> matches = new java.util.TreeSet<>();
        final Matcher matcher = pattern.matcher(value);
        while (matcher.find()) {
            matches.add(matcher.group());
        }
        return Set.copyOf(matches);
    }

    private static boolean negationParity(String source, String target) {
        return containsNegation(source) == containsNegation(target);
    }

    private static boolean containsNegation(String value) {
        final String normalized = Normalizer.normalize(value, Normalizer.Form.NFKC)
                .toLowerCase(Locale.ROOT);
        for (String token : NEGATION_TOKENS) {
            if (Pattern.compile("\\b" + Pattern.quote(token) + "\\b").matcher(normalized).find()) {
                return true;
            }
        }
        return false;
    }

    private static double cosine(double[] left, double[] right) {
        if (left == null || right == null || left.length == 0 || left.length != right.length) {
            return Double.NaN;
        }

        double dot = 0.0;
        double leftMagnitudeSquared = 0.0;
        double rightMagnitudeSquared = 0.0;

        for (int index = 0; index < left.length; index++) {
            if (!Double.isFinite(left[index]) || !Double.isFinite(right[index])) {
                return Double.NaN;
            }
            dot += left[index] * right[index];
            leftMagnitudeSquared += left[index] * left[index];
            rightMagnitudeSquared += right[index] * right[index];
        }

        if (leftMagnitudeSquared == 0.0 || rightMagnitudeSquared == 0.0) {
            return Double.NaN;
        }

        return dot / Math.sqrt(leftMagnitudeSquared * rightMagnitudeSquared);
    }
}
