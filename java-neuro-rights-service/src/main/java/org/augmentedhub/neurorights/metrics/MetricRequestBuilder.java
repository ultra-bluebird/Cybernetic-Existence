package org.augmentedhub.neurights.metrics;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class MetricRequestBuilder {
    private final MetricContract contract;
    private final String metric;
    private final Map<String, Object> input = new LinkedHashMap<>();
    private final Map<String, Object> options = new LinkedHashMap<>();

    private MetricRequestBuilder(
        final MetricContract contract,
        final String metric
    ) throws MetricContractException {
        this.contract = Objects.requireNonNull(contract, "contract");
        this.metric = Objects.requireNonNull(metric, "metric");

        if (!contract.isSupportedMetric(metric)) {
            throw new MetricContractException(
                "unsupported_metric",
                "The requested metric is not permitted by the pinned contract."
            );
        }
    }

    public static MetricRequestBuilder forMetric(
        final MetricContract contract,
        final String metric
    ) throws MetricContractException {
        return new MetricRequestBuilder(contract, metric);
    }

    public MetricRequestBuilder putAggregateNumber(
        final String field,
        final double value
    ) throws MetricContractException {
        requirePermittedInputField(field, MetricContract.FieldType.NUMBER);

        if (!Double.isFinite(value)) {
            throw new MetricContractException(
                "invalid_input",
                "The aggregate numeric input is not finite."
            );
        }

        final MetricContract.FieldRule rule = contract.inputRule(metric, field);

        if (rule.minimum().isPresent() && value < rule.minimum().get()) {
            throw new MetricContractException(
                "invalid_input",
                "The aggregate numeric input is below the permitted range."
            );
        }

        if (rule.maximum().isPresent() && value > rule.maximum().get()) {
            throw new MetricContractException(
                "invalid_input",
                "The aggregate numeric input is above the permitted range."
            );
        }

        input.put(field, value);
        return this;
    }

    public MetricRequestBuilder putAggregateEnum(
        final String field,
        final String value
    ) throws MetricContractException {
        requirePermittedInputField(field, MetricContract.FieldType.STRING);

        final MetricContract.FieldRule rule = contract.inputRule(metric, field);

        if (!rule.allowedValues().contains(value)) {
            throw new MetricContractException(
                "invalid_input",
                "The aggregate enum input is not a permitted contract value."
            );
        }

        input.put(field, value);
        return this;
    }

    public MetricRequestBuilder putOption(
        final String option,
        final Object value
    ) throws MetricContractException {
        if (!contract.allowedOptions(metric).contains(option)) {
            throw new MetricContractException(
                "unknown_option",
                "The option is not permitted by the pinned contract."
            );
        }

        validateNoProhibitedKeys(Map.of(option, value));
        options.put(option, value);
        return this;
    }

    public MetricDispatchClient.MetricDispatchRequest build()
        throws MetricContractException {
        validateRequiredFields();
        validateNoProhibitedKeys(input);
        validateNoProhibitedKeys(options);

        return new MetricDispatchClient.MetricDispatchRequest(
            metric,
            Map.copyOf(input),
            Map.copyOf(options),
            contract.contractVersion(),
            contract.contractSha256()
        );
    }

    private void requirePermittedInputField(
        final String field,
        final MetricContract.FieldType expectedType
    ) throws MetricContractException {
        final MetricContract.FieldRule rule = contract.inputRule(metric, field);

        if (rule == null) {
            throw new MetricContractException(
                "unknown_field",
                "The input field is not permitted for this metric."
            );
        }

        if (rule.type() != expectedType) {
            throw new MetricContractException(
                "invalid_input",
                "The input field does not accept this value type."
            );
        }
    }

    private void validateRequiredFields() throws MetricContractException {
        for (final MetricContract.FieldRule rule : contract.inputRules(metric)) {
            if (rule.required() && !input.containsKey(rule.name())) {
                throw new MetricContractException(
                    "missing_required_field",
                    "A required aggregate metric field is missing."
                );
            }
        }
    }

    private void validateNoProhibitedKeys(
        final Map<String, Object> tree
    ) throws MetricContractException {
        final ProhibitedKeyValidator.ValidationResult validation =
            ProhibitedKeyValidator.validate(tree);

        if (!validation.allowed()) {
            throw new MetricContractException(
                "prohibited_key",
                "The aggregate-only request contract rejected a field."
            );
        }
    }

    public static final class MetricContractException extends Exception {
        private final String code;

        public MetricContractException(
            final String code,
            final String message
        ) {
            super(message);
            this.code = Objects.requireNonNull(code, "code");
        }

        public String code() {
            return code;
        }
    }
}
