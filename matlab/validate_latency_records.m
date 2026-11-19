function report = validate_latency_records(records)
%VALIDATE_LATENCY_RECORDS Offline validator and bounded summarizer.
% records: struct array of latency records conforming to
%          latency-record.schema.json.
% This function rejects invalid records, records valid ones, and only
% summarizes same-category primary-reported values with known endpoints.
% It never infers missing start/end events, sums cross-category values,
% or aggregates secondary or unresolved rows into primary summaries.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent, verified identity,
% execution evidence, or authority.

arguments
    records {mustBeA(records,"struct")}
end

if isempty(records)
    error("AugmentedHub:InputShape","Supply at least one record.");
end

N = numel(records);
validation = false(N,1);
reasons = strings(N,1);

quantityCategories = ["decoder_output_increment", ...
    "processing_execution_duration","feature_window_duration", ...
    "command_update_interval","communication_delay", ...
    "adjustment_latency","decoder_latency","output_onset_latency", ...
    "output_completion_latency","model_parameter_update_interval", ...
    "stimulation_state_dwell_duration","stimulation_energy_comparison", ...
    "operating_timescale","ramp_rate","ambiguous_quantity"];

evidenceBases = ["primary_reported_measurement", ...
    "primary_reported_schedule","primary_reported_model_result", ...
    "secondary_source_report","analyst_calculation", ...
    "unresolved_source_passage"];

sourceVersions = ["final_published_article", ...
    "preprint_identified_version","supplementary_information", ...
    "extended_data","secondary_review"];

endpointStatuses = ["fully_defined","partially_defined", ...
    "not_reported_in_reviewed_material","source_location_unresolved"];

requiredFields = ["canonicalStudy","sourceVersion","sourceLocation", ...
    "quantityCategory","evidenceBasis","taskCondition", ...
    "onlineOrOffline","implementationLocation","startEvent", ...
    "endEvent","endpointStatus","reportedStatistic", ...
    "uncertaintyDefinition","reportedValue","unit", ...
    "missingInformation","interpretationLimit"];

for index = 1:N
    rec = records(index);
    failReason = "";

    if ~all(isfield(rec,requiredFields))
        failReason = "missing_required_field";
    elseif ~any(rec.quantityCategory == quantityCategories)
        failReason = "unknown_quantity_category";
    elseif ~any(rec.evidenceBasis == evidenceBases)
        failReason = "unknown_evidence_basis";
    elseif ~any(rec.sourceVersion == sourceVersions)
        failReason = "unknown_source_version";
    elseif ~any(rec.endpointStatus == endpointStatuses)
        failReason = "unknown_endpoint_status";
    elseif isempty(rec.missingInformation) || ...
            any(strlength(rec.missingInformation) == 0)
        failReason = "missing_information_must_be_explicit";
    else
        rec_quantity = rec.quantityCategory;
        rec_evidence = rec.evidenceBasis;
        rec_endpoint = rec.endpointStatus;

        % Increment must not be treated as latency.
        if rec_quantity == "decoder_output_increment" && ...
                rec_evidence == "primary_reported_measurement"
            failReason = "increment_cannot_be_primary_measured_latency";
        end

        % Ramp rate is not a latency.
        if rec_quantity == "ramp_rate" && ...
                isfield(rec,"interpretationLimit") && ...
                contains(rec.interpretationLimit,"latency","IgnoreCase",true)
            failReason = "ramp_rate_cannot_be_classified_as_latency";
        end

        % Analyzed total from unresolved rows is prohibited.
        if rec_evidence == "analyst_calculation" && ...
                any(strcmp(rec.startEvent.definitionStatus, ...
                    ["not_reported","partially_defined"])) && ...
                any(strcmp(rec.endEvent.definitionStatus, ...
                    ["not_reported","partially_defined"]))
            failReason = "analyst_calculation_requires_defined_endpoints";
        end

        % Fully defined endpoints are required for "primary_reported_measurement"
        % of latency-category quantities.
        latencyCategories = ["adjustment_latency","decoder_latency", ...
            "output_onset_latency","output_completion_latency"];
        if rec_evidence == "primary_reported_measurement" && ...
                any(rec_quantity == latencyCategories) && ...
                rec_endpoint ~= "fully_defined"
            failReason = "measured_latency_requires_fully_defined_endpoints";
        end
    end

    if failReason == ""
        validation(index) = true;
    else
        reasons(index) = failReason;
    end
end

validMask = validation;
category = strings(N,1);
for index = 1:N
    if validMask(index)
        category(index) = records(index).quantityCategory;
    end
end

uniqueCategories = unique(category(validMask & strlength(category) > 0));
summaryRows = cell(numel(uniqueCategories),6);

for index = 1:numel(uniqueCategories)
    cat = uniqueCategories(index);
    sel = validMask & category == cat;
    subset = records(sel);

    primaryMeasured = 0;
    primaryScheduled = 0;
    secondary = 0;
    unresolved = 0;

    for j = 1:numel(subset)
        if subset(j).evidenceBasis == "primary_reported_measurement"
            primaryMeasured = primaryMeasured + 1;
        elseif subset(j).evidenceBasis == "primary_reported_schedule"
            primaryScheduled = primaryScheduled + 1;
        elseif subset(j).evidenceBasis == "secondary_source_report"
            secondary = secondary + 1;
        elseif subset(j).evidenceBasis == "unresolved_source_passage"
            unresolved = unresolved + 1;
        end
    end

    summaryRows(index,:) = {cat,numel(subset),primaryMeasured, ...
        primaryScheduled,secondary,unresolved};
end

report = struct();
report.mode = "offline-latency-record-validation";
report.schemaVersion = "0.1.0";
report.recordCount = N;
report.validCount = sum(validMask);
report.invalidCount = sum(~validMask);
report.validity = validation;
report.reasons = reasons;
report.crossStudyAggregationPerformed = false;
report.categorySummary = cell2table(summaryRows, ...
    "VariableNames",["category","total","primaryMeasured", ...
    "primaryScheduled","secondary","unresolved"]);
report.records = records;
report.computationalExecutionEstablished = false;
end
