function result = summarize_loop_latency(eventsSeconds, metadata)
% Columns:
% 1 physiological reference, 2 first acquisition, 3 features ready,
% 4 decoder ready, 5 output submitted, 6 output observed.
% NaN means unavailable. All present events must share one clock domain.
% Physiological reference and output observation require declared methods.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Attribution is credit metadata, not consent or operating authority.

arguments
    eventsSeconds (:,6) double
    metadata (1,1) struct
end

required = ["modality", "task", "condition", ...
    "clockDomain", "eventDefinitions", "timestampUncertaintySeconds"];

for name = required
    if ~isfield(metadata, char(name))
        error("AugmentedHub:MissingMetadata", ...
            "Missing metadata field: %s", name);
    end
end

textFields = ["modality", "task", "condition", "clockDomain"];
for name = textFields
    value = string(metadata.(char(name)));
    if ~isscalar(value) || ismissing(value) || strlength(value) == 0
        error("AugmentedHub:InvalidMetadata", ...
            "%s must be a nonempty text scalar.", name);
    end
end

definitions = string(metadata.eventDefinitions);
if numel(definitions) ~= 6 || ...
        any(ismissing(definitions), "all") || ...
        any(strlength(definitions) == 0, "all")
    error("AugmentedHub:InvalidDefinitions", ...
        "Supply six nonempty event definitions.");
end

uncertainty = metadata.timestampUncertaintySeconds;
if ~isnumeric(uncertainty) || ~isreal(uncertainty) || ...
        numel(uncertainty) ~= 6 || ...
        any(~isfinite(uncertainty), "all") || ...
        any(uncertainty < 0, "all")
    error("AugmentedHub:InvalidUncertainty", ...
        "Supply six finite nonnegative uncertainty bounds in seconds.");
end

if isempty(eventsSeconds) || ~isreal(eventsSeconds) || ...
        any(isinf(eventsSeconds), "all")
    error("AugmentedHub:InvalidEvents", ...
        "Supply real timestamps; only NaN may mark unavailable events.");
end

for row = 1:size(eventsSeconds, 1)
    present = eventsSeconds(row, ~isnan(eventsSeconds(row, :)));
    if any(diff(present) < 0)
        error("AugmentedHub:EventOrder", ...
            "Present events must follow the declared event order.");
    end
end

pairs = [1 2; 2 3; 3 4; 4 5; 5 6; 2 6; 1 6];
names = ["reference_to_acquisition"; "acquisition_to_features"; ...
    "features_to_decoder"; "decoder_to_submission"; ...
    "submission_to_observed"; "acquisition_to_observed"; ...
    "reference_to_observed"];

durations = NaN(size(eventsSeconds, 1), size(pairs, 1));
count = zeros(size(pairs, 1), 1);
medianSeconds = NaN(size(count));
p95Seconds = NaN(size(count));
p99Seconds = NaN(size(count));
differenceUncertainty = zeros(size(count));

for index = 1:size(pairs, 1)
    a = pairs(index, 1);
    b = pairs(index, 2);
    durations(:, index) = eventsSeconds(:, b) - eventsSeconds(:, a);
    values = sort(durations(~isnan(durations(:, index)), index));
    count(index) = numel(values);
    differenceUncertainty(index) = uncertainty(a) + uncertainty(b);

    if ~isempty(values)
        medianSeconds(index) = median(values);
        p95Seconds(index) = values(max(1, ceil(0.95*numel(values))));
        p99Seconds(index) = values(max(1, ceil(0.99*numel(values))));
    end
end

result = struct();
result.metadata = metadata;
result.quantileConvention = "empirical-nearest-rank";
result.summary = table(names, count, medianSeconds, p95Seconds, ...
    p99Seconds, differenceUncertainty);
result.durationsSeconds = durations;
result.hardwareControlAvailable = false;
end
