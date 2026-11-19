function test_report_decoder_task_suite()
% Synthetic paired opportunities, not neural performance data.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

trials = table();
trials.task = ["bounded";"bounded";"broad";"broad"];
trials.specialistInScope = [true;true;false;false];
trials.specialistAccepted = [true;true;false;false];
trials.generalAccepted = true(4,1);
trials.specialistCorrect = [true;true;false;false];
trials.generalCorrect = [true;false;true;true];
trials.specialistBaseSeconds = [1;1;4;4];
trials.generalBaseSeconds = [2;2;2;2];
trials.specialistSwitchSeconds = [0;0;3;3];
trials.generalSwitchSeconds = zeros(4,1);

r = report_decoder_task_suite(trials);
aggregate = r.summary.isAggregate;

specialist = r.summary(aggregate & ...
    r.summary.design == "specialist",:);
general = r.summary(aggregate & ...
    r.summary.design == "general",:);

assert(specialist.conditionalAccuracy == 1);
assert(specialist.coverage == 0.5);
assert(specialist.correctOpportunityFraction == 0.5);
assert(general.correctOpportunityFraction == 0.75);
assert(specialist.meanSwitchSeconds == 1.5);

% High conditional accuracy does not erase failed/out-of-scope opportunities.
assert(specialist.conditionalAccuracy > general.conditionalAccuracy);
assert(specialist.correctOpportunityFraction < ...
    general.correctOpportunityFraction);

invalid = trials;
invalid.specialistCorrect(3) = true;
caught = false;
try
    report_decoder_task_suite(invalid);
catch exception
    caught = strcmp(exception.identifier, ...
        "AugmentedHub:InputConsistency");
end
assert(caught);
end
