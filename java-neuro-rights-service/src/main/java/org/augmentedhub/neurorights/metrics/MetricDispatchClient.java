package org.augmentedhub.neurorights.metrics;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class MetricDispatchClient {
    private static final Duration CONNECT_TIMEOUT = Duration.ofMillis(500);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(2);
    private static final int MAX_REQUEST_BYTES = 65_536;
    private static final int MAX_RESPONSE_BYTES = 1_048_576;

    private static final Set<String> LITERAL_LOOPBACK_HOSTS = Set.of(
        "127.0.0.1",
        "::1"
    );

    private final URI dispatcherUri;
    private final URI contractUri;
    private final HttpClient httpClient;
    private final MetricContract contract;
    private final StrictJsonCodec jsonCodec;

    public MetricDispatchClient(
        final URI dispatcherUri,
        final MetricContract contract,
        final StrictJsonCodec jsonCodec
    ) throws MetricDispatchException {
        this(
            dispatcherUri,
            HttpClient.newBuilder()
                .connectTimeout(CONNECT_TIMEOUT)
                .followRedirects(HttpClient.Redirect.NEVER)
                .version(HttpClient.Version.HTTP_1_1)
                .build(),
            contract,
            jsonCodec
        );
    }

    MetricDispatchClient(
        final URI dispatcherUri,
        final HttpClient httpClient,
        final MetricContract contract,
        final StrictJsonCodec jsonCodec
    ) throws MetricDispatchException {
        this.dispatcherUri = validateLiteralLoopbackEndpoint(dispatcherUri);
        this.contractUri = createContractUri(this.dispatcherUri);
        this.httpClient = Objects.requireNonNull(httpClient, "httpClient");
        this.contract = Objects.requireNonNull(contract, "contract");
        this.jsonCodec = Objects.requireNonNull(jsonCodec, "jsonCodec");
    }

    public void verifyDispatcherContract()
        throws IOException, InterruptedException, MetricDispatchException {
        final HttpRequest request = HttpRequest.newBuilder(contractUri)
            .timeout(REQUEST_TIMEOUT)
            .header("Accept", "application/json")
            .header("Accept-Encoding", "identity")
            .GET()
            .build();

        final HttpResponse<byte[]> response = httpClient.send(
            request,
            HttpResponse.BodyHandlers.ofByteArray()
        );

        validateJsonResponse(response);

        final Map<String, Object> document = jsonCodec.readObject(response.body());
        final int remoteContractVersion = requireNumber(
            document,
            "contract_version"
        ).intValue();
        final String remoteContractSha256 = requireSha256(
            document,
            "contract_sha256"
        );

        if (remoteContractVersion != contract.contractVersion()
            || !remoteContractSha256.equals(contract.contractSha256())) {
            throw new MetricDispatchException(
                "contract_mismatch",
                "The local dispatcher contract does not match the pinned adapter contract."
            );
        }
    }

    public MetricDispatchResponse dispatch(
        final MetricDispatchRequest request
    ) throws IOException, InterruptedException, MetricDispatchException {
        Objects.requireNonNull(request, "request");

        if (request.contractVersion() != contract.contractVersion()
            || !request.contractSha256().equals(contract.contractSha256())) {
            throw new MetricDispatchException(
                "contract_mismatch",
                "The request contract identity does not match the pinned adapter contract."
            );
        }

        contract.validateRequest(
            request.metric(),
            request.input(),
            request.options()
        );

        final byte[] requestBody = jsonCodec.writeUtf8(request.toJsonTree());

        if (requestBody.length > MAX_REQUEST_BYTES) {
            throw new MetricDispatchException(
                "request_too_large",
                "The metric request exceeds the configured size limit."
            );
        }

        final HttpRequest httpRequest = HttpRequest.newBuilder(dispatcherUri)
            .timeout(REQUEST_TIMEOUT)
            .header("Accept", "application/json")
            .header("Content-Type", "application/json; charset=utf-8")
            .header("Accept-Encoding", "identity")
            .POST(HttpRequest.BodyPublishers.ofByteArray(requestBody))
            .build();

        final HttpResponse<byte[]> response = httpClient.send(
            httpRequest,
            HttpResponse.BodyHandlers.ofByteArray()
        );

        validateJsonResponse(response);

        final Map<String, Object> responseTree = jsonCodec.readObject(
            response.body()
        );

        contract.validateResponse(responseTree);
        GovernanceEnvelopeFactory.requireStandardGovernance(responseTree);

        final MetricDispatchResponse metricResponse =
            MetricDispatchResponse.fromJsonTree(responseTree);

        if (metricResponse.contractVersion() != contract.contractVersion()
            || !metricResponse.contractSha256().equals(contract.contractSha256())) {
            throw new MetricDispatchException(
                "contract_mismatch",
                "The dispatcher response contract identity does not match the pinned adapter contract."
            );
        }

        return metricResponse;
    }

    private static URI validateLiteralLoopbackEndpoint(
        final URI candidate
    ) throws MetricDispatchException {
        Objects.requireNonNull(candidate, "candidate");

        if (!"http".equals(candidate.getScheme())) {
            throw new MetricDispatchException(
                "invalid_endpoint",
                "The dispatcher endpoint must use HTTP on a literal loopback address."
            );
        }

        final String host = candidate.getHost();

        if (host == null || !LITERAL_LOOPBACK_HOSTS.contains(host)) {
            throw new MetricDispatchException(
                "invalid_endpoint",
                "The dispatcher endpoint host must be 127.0.0.1 or ::1."
            );
        }

        if (candidate.getPort() < 1 || candidate.getPort() > 65_535) {
            throw new MetricDispatchException(
                "invalid_endpoint",
                "The dispatcher endpoint must contain an explicit valid port."
            );
        }

        if (candidate.getUserInfo() != null
            || candidate.getRawQuery() != null
            || candidate.getRawFragment() != null) {
            throw new MetricDispatchException(
                "invalid_endpoint",
                "The dispatcher endpoint must not contain user information, a query, or a fragment."
            );
        }

        if (!candidate.getPath().startsWith("/")) {
            throw new MetricDispatchException(
                "invalid_endpoint",
                "The dispatcher endpoint path must be absolute."
            );
        }

        return candidate.normalize();
    }

    private static URI createContractUri(
        final URI dispatchUri
    ) throws MetricDispatchException {
        try {
            return new URI(
                dispatchUri.getScheme(),
                null,
                dispatchUri.getHost(),
                dispatchUri.getPort(),
                "/v1/metrics/contract",
                null,
                null
            );
        } catch (final URISyntaxException exception) {
            throw new MetricDispatchException(
                "invalid_endpoint",
                "The dispatcher contract endpoint could not be constructed."
            );
        }
    }

    private static void validateJsonResponse(
        final HttpResponse<byte[]> response
    ) throws MetricDispatchException {
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new MetricDispatchException(
                "dispatcher_http_error",
                "The local dispatcher returned a non-success HTTP status."
            );
        }

        final String contentType = response.headers()
            .firstValue("Content-Type")
            .orElse("")
            .toLowerCase(Locale.ROOT);

        if (!contentType.startsWith("application/json")) {
            throw new MetricDispatchException(
                "invalid_response_content_type",
                "The local dispatcher did not return JSON content."
            );
        }

        final String contentEncoding = response.headers()
            .firstValue("Content-Encoding")
            .orElse("identity");

        if (!"identity".equalsIgnoreCase(contentEncoding)) {
            throw new MetricDispatchException(
                "unsupported_response_encoding",
                "The local dispatcher returned an unsupported content encoding."
            );
        }

        if (response.body().length > MAX_RESPONSE_BYTES) {
            throw new MetricDispatchException(
                "response_too_large",
                "The local dispatcher response exceeds the configured size limit."
            );
        }
    }

    private static String requireString(
        final Map<String, Object> object,
        final String fieldName
    ) throws MetricDispatchException {
        final Object value = object.get(fieldName);

        if (!(value instanceof String stringValue) || stringValue.isBlank()) {
            throw new MetricDispatchException(
                "invalid_response",
                "The local dispatcher response is malformed."
            );
        }

        return stringValue;
    }

    private static String requireSha256(
        final Map<String, Object> object,
        final String fieldName
    ) throws MetricDispatchException {
        final String value = requireString(object, fieldName);

        if (!value.matches("^[a-f0-9]{64}$")) {
            throw new MetricDispatchException(
                "invalid_response",
                "The local dispatcher response is malformed."
            );
        }

        return value;
    }

    private static Number requireNumber(
        final Map<String, Object> object,
        final String fieldName
    ) throws MetricDispatchException {
        final Object value = object.get(fieldName);

        if (!(value instanceof Number numberValue)) {
            throw new MetricDispatchException(
                "invalid_response",
                "The local dispatcher response is malformed."
            );
        }

        return numberValue;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> requireObject(
        final Map<String, Object> object,
        final String fieldName
    ) throws MetricDispatchException {
        final Object value = object.get(fieldName);

        if (!(value instanceof Map<?, ?> rawObject)) {
            throw new MetricDispatchException(
                "invalid_response",
                "The local dispatcher response is malformed."
            );
        }

        final Map<String, Object> copiedObject = new LinkedHashMap<>();

        for (final Map.Entry<?, ?> entry : rawObject.entrySet()) {
            if (!(entry.getKey() instanceof String key)) {
                throw new MetricDispatchException(
                    "invalid_response",
                    "The local dispatcher response is malformed."
                );
            }

            copiedObject.put(key, entry.getValue());
        }

        return Map.copyOf(copiedObject);
    }

    public interface StrictJsonCodec {
        byte[] writeUtf8(Map<String, Object> value)
            throws MetricDispatchException;

        Map<String, Object> readObject(byte[] value)
            throws MetricDispatchException;
    }

    public record MetricDispatchRequest(
        String metric,
        Map<String, Object> input,
        Map<String, Object> options,
        int contractVersion,
        String contractSha256
    ) {
        public MetricDispatchRequest {
            Objects.requireNonNull(metric, "metric");
            Objects.requireNonNull(input, "input");
            Objects.requireNonNull(options, "options");
            Objects.requireNonNull(contractSha256, "contractSha256");

            if (metric.isBlank()) {
                throw new IllegalArgumentException(
                    "metric must not be blank"
                );
            }

            if (contractVersion < 1) {
                throw new IllegalArgumentException(
                    "contractVersion must be greater than zero"
                );
            }

            if (!contractSha256.matches("^[a-f0-9]{64}$")) {
                throw new IllegalArgumentException(
                    "contractSha256 must be lowercase SHA-256 hexadecimal"
                );
            }

            input = Map.copyOf(input);
            options = Map.copyOf(options);
        }

        public Map<String, Object> toJsonTree() {
            final Map<String, Object> request = new LinkedHashMap<>();

            request.put("metric", metric);
            request.put("input", input);
            request.put("options", options);
            request.put("contract_version", contractVersion);
            request.put("contract_sha256", contractSha256);

            return Map.copyOf(request);
        }
    }

    public record MetricDispatchResponse(
        String metric,
        int contractVersion,
        String contractSha256,
        Map<String, Object> result,
        Map<String, Object> governance
    ) {
        public MetricDispatchResponse {
            Objects.requireNonNull(metric, "metric");
            Objects.requireNonNull(contractSha256, "contractSha256");
            Objects.requireNonNull(result, "result");
            Objects.requireNonNull(governance, "governance");

            result = Map.copyOf(result);
            governance = Map.copyOf(governance);
        }

        static MetricDispatchResponse fromJsonTree(
            final Map<String, Object> response
        ) throws MetricDispatchException {
            return new MetricDispatchResponse(
                requireString(response, "metric"),
                requireNumber(response, "contract_version").intValue(),
                requireSha256(response, "contract_sha256"),
                requireObject(response, "result"),
                requireObject(response, "governance")
            );
        }
    }

    public static final class MetricDispatchException extends Exception {
        private final String code;

        public MetricDispatchException(
            final String code,
            final String safeMessage
        ) {
            super(safeMessage);
            this.code = Objects.requireNonNull(code, "code");
        }

        public String code() {
            return code;
        }
    }
}
