function report = report_decoder_task_suite(trials)
%REPORT_DECODER_TASK_SUITE Offline paired specialist/general comparison.
% Required columns:
% task: nonempty string column
% specialistInScope: logical
% specialistAccepted, generalAccepted: logical
% specialistCorrect, generalCorrect: logical
% specialistBaseSeconds, generalBaseSeconds: nonnegative finite doubles
% specialistSwitchSeconds, generalSwitchSeconds: nonnegative finite doubles
%
% Each row is a paired opportunity with independently annotated correctness.
% Durations describe observed benchmark time, not uncensored time-to-success.
% No training, model selection, weighting, inference, or device control.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    trials {mustBeA(trials,"table")}
end

logicalFields = ["specialistInScope","specialistAccepted", ...
    "generalAccepted","specialistCorrect","generalCorrect"];
timeFields = ["specialistBaseSeconds","generalBaseSeconds", ...
    "specialistSwitchSeconds","generalSwitchSeconds"];
required = ["task",logicalFields,timeFields];

if isempty(trials) || ...
        ~all(ismember(required,string(trials.Properties.VariableNames)))
    error("AugmentedHub:InputConsistency", ...
        "Supply a nonempty table with all required columns.");
end

N = height(trials);
if ~isa(trials.task,"string") || size(trials.task,2) ~= 1 || ...
        any(ismissing(trials.task)) || any(strlength(trials.task) == 0)
    error("AugmentedHub:InputType", ...
        "Task labels must be nonempty string-column entries.");
end

for field = logicalFields
    value = trials.(char(field));
    if ~isa(value,"logical") || ~isequal(size(value),[N,1])
        error("AugmentedHub:InputType", ...
            "Outcome and scope fields must be logical columns.");
    end
end

for field = timeFields
    value = trials.(char(field));
    if ~isa(value,"double") || ~isreal(value) || ...
            ~isequal(size(value),[N,1]) || ...
            any(~isfinite(value)) || any(value < 0)
        error("AugmentedHub:InputType", ...
            "Duration fields must be finite nonnegative double columns.");
    end
end

if any(trials.specialistCorrect & ~trials.specialistAccepted) || ...
        any(trials.generalCorrect & ~trials.generalAccepted)
    error("AugmentedHub:InputConsistency", ...
        "An unaccepted answer cannot be marked correct.");
end

specialistTotal = ...
    trials.specialistBaseSeconds+trials.specialistSwitchSeconds;
generalTotal = ...
    trials.generalBaseSeconds+trials.generalSwitchSeconds;

if any(~isfinite(specialistTotal)) || any(~isfinite(generalTotal))
    error("AugmentedHub:NumericalRange", ...
        "Total durations exceeded finite arithmetic.");
end

tasks = unique(trials.task,"stable");
rows = cell(2*(numel(tasks)+1),12);
position = 0;

for group = 0:numel(tasks)
    aggregate = group == 0;
    if aggregate
        selected = true(N,1);
        label = "aggregate";
    else
        label = tasks(group);
        selected = trials.task == label;
    end

    for design = ["specialist","general"]
        position = position+1;
        accepted = trials.(char(design+"Accepted"))(selected);
        correct = trials.(char(design+"Correct"))(selected);
        base = trials.(char(design+"BaseSeconds"))(selected);
        switching = trials.(char(design+"SwitchSeconds"))(selected);
        total = base+switching;

        count = sum(selected);
        acceptedCount = sum(accepted);
        conditionalAccuracy = NaN;
        if acceptedCount > 0
            conditionalAccuracy = sum(correct)/acceptedCount;
        end

        rows(position,:) = {aggregate,label,design,count, ...
            mean(trials.specialistInScope(selected)), ...
            mean(accepted),mean(correct),conditionalAccuracy, ...
            mean(base),mean(switching),median(total),mean(total)};
    end
end

report = struct();
report.documentVersion = "0.1.0";
report.mode = "offline-paired-task-suite-description";
report.aggregateWeighting = "one equal weight per supplied paired opportunity";
report.correctnessAnnotationsVerified = false;
report.scopeFrozenBeforeEvaluationVerified = false;
report.uncertaintyEstimated = false;
report.winnerSelected = false;

report.summary = cell2table(rows,"VariableNames", ...
    ["isAggregate","task","design","opportunityCount", ...
    "specialistScopeFraction","coverage","correctOpportunityFraction", ...
    "conditionalAccuracy","meanBaseSeconds","meanSwitchSeconds", ...
    "medianObservedTotalSeconds","meanObservedTotalSeconds"]);

report.pairedObservedTimeDifferenceSeconds = specialistTotal-generalTotal;
report.pairedCorrectnessDifference = ...
    double(trials.specialistCorrect)-double(trials.generalCorrect);
report.pairedScopeMembership = trials.specialistInScope;
end
