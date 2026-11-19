function report = audit_communication_repairs(episodes, actions)
%AUDIT_COMMUNICATION_REPAIRS Offline repair timing and action accounting.
% episodes columns:
% breakdownSeconds, recognitionSeconds, repairStartSeconds,
% outcomeSeconds, observationEndSeconds: double columns
% outcome: "resolved", "cancelled", or "pending"
%
% Unknown recognition/repair start may be NaN.
% Pending episodes must have NaN outcomeSeconds.
%
% actions columns:
% episodeRow, startSeconds, endSeconds, activations: finite doubles
% strategy: declared strategy string
% actor: "person", "partner", or "system"
%
% Clock/timebase consistency and outcome annotations are external obligations.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    episodes {mustBeA(episodes,"table")}
    actions {mustBeA(actions,"table")}
end

episodeNumeric = ["breakdownSeconds","recognitionSeconds", ...
    "repairStartSeconds","outcomeSeconds","observationEndSeconds"];
actionNumeric = ["episodeRow","startSeconds","endSeconds","activations"];

if height(episodes) == 0 || ...
        ~all(ismember([episodeNumeric,"outcome"], ...
        string(episodes.Properties.VariableNames))) || ...
        ~all(ismember([actionNumeric,"strategy","actor"], ...
        string(actions.Properties.VariableNames)))
    error("AugmentedHub:InputConsistency", ...
        "Required episode or action columns are missing.");
end

for name = episodeNumeric
    value = episodes.(char(name));
    if ~isa(value,"double") || ~isreal(value) || ...
            size(value,2) ~= 1 || any(isinf(value))
        error("AugmentedHub:InputType", ...
            "Episode times must be real double columns; NaN marks unknown.");
    end
end

for name = actionNumeric
    value = actions.(char(name));
    if ~isa(value,"double") || ~isreal(value) || ...
            size(value,2) ~= 1 || any(~isfinite(value))
        error("AugmentedHub:InputType", ...
            "Action numeric columns must be finite real doubles.");
    end
end

mustBeTextColumn(episodes.outcome);
mustBeTextColumn(actions.strategy);
mustBeTextColumn(actions.actor);

strategies = ["repeat","rephrase","edit","spell_or_select","cancel", ...
    "switch_modality","request_support","clarify_destination", ...
    "system_recovery"];

if any(~ismember(episodes.outcome,["resolved","cancelled","pending"])) || ...
        any(~ismember(actions.strategy,strategies)) || ...
        any(~ismember(actions.actor,["person","partner","system"]))
    error("AugmentedHub:InputValue", "Unknown annotation category.");
end

N = height(episodes);
rows = actions.episodeRow;

if any(rows < 1 | rows > N | rows ~= fix(rows)) || ...
        any(actions.endSeconds < actions.startSeconds) || ...
        any(actions.activations < 0 | ...
        actions.activations ~= fix(actions.activations))
    error("AugmentedHub:InputValue", "Invalid action bounds or counts.");
end

observedDuration = zeros(N,1);
resolutionDuration = NaN(N,1);
recognitionDelay = NaN(N,1);
initiationDelay = NaN(N,1);
personActive = zeros(N,1);
allActive = zeros(N,1);
actionCount = zeros(N,1);
personActivations = zeros(N,1);

for index = 1:N
    b = episodes.breakdownSeconds(index);
    stop = episodes.observationEndSeconds(index);
    recognition = episodes.recognitionSeconds(index);
    repair = episodes.repairStartSeconds(index);
    outcomeTime = episodes.outcomeSeconds(index);
    pending = episodes.outcome(index) == "pending";

    if ~isfinite(b) || ~isfinite(stop) || stop < b
        error("AugmentedHub:InputValue", ...
            "Every episode requires an ordered observed time span.");
    end

    if pending
        if ~isnan(outcomeTime)
            error("AugmentedHub:InputConsistency", ...
                "Pending episodes must have unavailable outcome time.");
        end
        terminal = stop;
    else
        if ~isfinite(outcomeTime) || outcomeTime < b || outcomeTime > stop
            error("AugmentedHub:InputConsistency", ...
                "Completed outcomes must lie within the observed episode.");
        end
        terminal = outcomeTime;
    end

    if isfinite(recognition)
        if recognition < b || recognition > terminal
            error("AugmentedHub:InputValue", "Invalid recognition time.");
        end
        recognitionDelay(index) = recognition-b;
    end

    if isfinite(repair)
        if repair < b || repair > terminal
            error("AugmentedHub:InputValue", "Invalid repair-start time.");
        end
        initiationDelay(index) = repair-b;
    end

    selected = rows == index;
    if any(selected)
        if ~isfinite(repair) || ...
                any(actions.startSeconds(selected) < repair) || ...
                any(actions.endSeconds(selected) > terminal)
            error("AugmentedHub:InputConsistency", ...
                "Actions must lie within the declared repair episode.");
        end
    end

    observedDuration(index) = terminal-b;
    if episodes.outcome(index) == "resolved"
        resolutionDuration(index) = terminal-b;
    end

    personRows = selected & actions.actor == "person";
    actionCount(index) = sum(selected);
    personActivations(index) = sum(actions.activations(personRows));
    allActive(index) = intervalUnionLength( ...
        actions.startSeconds(selected),actions.endSeconds(selected));
    personActive(index) = intervalUnionLength( ...
        actions.startSeconds(personRows),actions.endSeconds(personRows));
end

report = struct();
report.mode = "offline-communication-repair-audit";
report.resolvedCount = sum(episodes.outcome == "resolved");
report.cancelledCount = sum(episodes.outcome == "cancelled");
report.pendingCount = sum(episodes.outcome == "pending");
report.outcomeAnnotationsVerified = false;
report.elapsedTimeIsSubjectiveEffort = false;
report.subjectiveEffortMeasured = false;
report.censoredDurationIsResolutionTime = false;

report.episodes = table( ...
    episodes.outcome,observedDuration,resolutionDuration, ...
    recognitionDelay,initiationDelay,allActive,personActive, ...
    actionCount,personActivations, ...
    "VariableNames",["outcome","observedDurationSeconds", ...
    "resolvedDurationSeconds","recognitionDelaySeconds", ...
    "repairInitiationDelaySeconds","allActorActiveSeconds", ...
    "personActiveSeconds","actionCount","personActivations"]);

report.actionTaxonomy = table( ...
    strategies.',arrayfun(@(s) sum(actions.strategy == s),strategies).', ...
    "VariableNames",["strategy","count"]);
end

function total = intervalUnionLength(starts,ends)
if isempty(starts)
    total = 0;
    return;
end

intervals = sortrows([starts,ends],[1,2]);
left = intervals(1,1);
right = intervals(1,2);
total = 0;

for index = 2:size(intervals,1)
    if intervals(index,1) <= right
        right = max(right,intervals(index,2));
    else
        total = total+right-left;
        left = intervals(index,1);
        right = intervals(index,2);
    end
end
total = total+right-left;
end

function mustBeTextColumn(value)
if ~isa(value,"string") || size(value,2) ~= 1 || ...
        any(ismissing(value)) || any(strlength(value) == 0)
    error("AugmentedHub:InputType", ...
        "Annotation categories must be nonmissing string columns.");
end
end
