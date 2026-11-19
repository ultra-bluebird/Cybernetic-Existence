function report = screen_assistive_lifecycle( ...
    inventory, scheduledHours, availableHours, qualifyingServiceHours)
%SCREEN_ASSISTIVE_LIFECYCLE Offline lifecycle screening aggregation.
% Each inventory row is an already allocated contribution.
% Required columns:
% stage: string
% primaryEnergyMJ, climateKgCO2e, waterLitres: nonnegative double or NaN
% dataBasis: "measured", "supplier", "modeled", or "assumed"
%
% NaN means unknown, not zero. Every declared stage must appear.
% A zero contribution must be explicitly supplied and justified externally.
% No factors, recycling credits, allocation rules, or service-quality
% requirements are invented by this function.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not certification or execution evidence.

arguments
    inventory {mustBeA(inventory,"table")}
    scheduledHours {mustBePositiveScalarDouble}
    availableHours {mustBeNonnegativeScalarDouble}
    qualifyingServiceHours {mustBePositiveScalarDouble}
end

stages = ["materials";"manufacturing";"transport"; ...
    "use";"maintenance";"end_of_life"];
impacts = ["primaryEnergyMJ","climateKgCO2e","waterLitres"];
required = ["stage","dataBasis",impacts];

if isempty(inventory) || ...
        ~all(ismember(required,string(inventory.Properties.VariableNames)))
    error("AugmentedHub:InputConsistency", ...
        "Supply a nonempty inventory with all required columns.");
end

if availableHours > scheduledHours || ...
        qualifyingServiceHours > availableHours
    error("AugmentedHub:InputValue", ...
        "Require qualifying <= available <= scheduled service hours.");
end

if ~isa(inventory.stage,"string") || ...
        size(inventory.stage,2) ~= 1 || ...
        any(ismissing(inventory.stage)) || ...
        any(~ismember(inventory.stage,stages))
    error("AugmentedHub:InputValue", ...
        "Use the declared lifecycle-stage vocabulary.");
end

basis = inventory.dataBasis;
if ~isa(basis,"string") || size(basis,2) ~= 1 || ...
        any(ismissing(basis)) || ...
        any(~ismember(basis,["measured","supplier","modeled","assumed"]))
    error("AugmentedHub:InputValue", ...
        "Supply one declared data-basis category per row.");
end

for name = impacts
    column = inventory.(char(name));
    if ~isa(column,"double") || ~isreal(column) || ...
            size(column,2) ~= 1 || any(isinf(column)) || ...
            any(column < 0)
        error("AugmentedHub:InputValue", ...
            "Impacts must be nonnegative doubles; NaN marks unknown.");
    end
end

stagePresent = ismember(stages,inventory.stage);
stageTotals = NaN(numel(stages),numel(impacts));
knownContribution = zeros(numel(impacts),1);
complete = false(numel(impacts),1);
fullTotal = NaN(numel(impacts),1);

for impact = 1:numel(impacts)
    values = inventory.(char(impacts(impact)));
    knownContribution(impact) = sum(values(~isnan(values)));

    for stage = 1:numel(stages)
        rows = inventory.stage == stages(stage);
        selected = values(rows);
        if any(rows) && all(~isnan(selected))
            stageTotals(stage,impact) = sum(selected);
        end
    end

    complete(impact) = all(stagePresent) && all(~isnan(values));
    if complete(impact)
        fullTotal(impact) = sum(values);
    end
end

if any(~isfinite(knownContribution)) || any(isinf(stageTotals),"all")
    error("AugmentedHub:NumericalRange", ...
        "Inventory aggregation exceeded finite arithmetic.");
end

perServiceHour = fullTotal/qualifyingServiceHours;
if any(isinf(perServiceHour))
    error("AugmentedHub:NumericalRange", ...
        "Per-service-hour values exceeded finite arithmetic.");
end

report = struct();
report.mode = "offline-lifecycle-screening";
report.functionalUnit = ...
    "One qualifying service hour under externally declared requirements";
report.scheduledHours = scheduledHours;
report.availableHours = availableHours;
report.qualifyingServiceHours = qualifyingServiceHours;
report.availabilityFraction = availableHours/scheduledHours;
report.qualifyingServiceFraction = qualifyingServiceHours/scheduledHours;
report.missingStages = stages(~stagePresent);
report.inputDataBasisCounts = table( ...
    ["measured";"supplier";"modeled";"assumed"], ...
    [sum(basis=="measured");sum(basis=="supplier"); ...
     sum(basis=="modeled");sum(basis=="assumed")], ...
    "VariableNames",["basis","rowCount"]);

report.stageContributions = array2table(stageTotals, ...
    "VariableNames",cellstr(impacts));
report.stageContributions = addvars( ...
    report.stageContributions,stages,"Before",1, ...
    "NewVariableNames","stage");

report.impactSummary = table( ...
    impacts.',knownContribution,complete,fullTotal,perServiceHour, ...
    "VariableNames",["impact","knownContributionOnly", ...
    "declaredBoundaryComplete","fullTotal","perQualifyingServiceHour"]);

report.inventoryAccuracyVerified = false;
report.allocationValidated = false;
report.uncertaintyEstimated = false;
report.fullLifecycleAssessmentEstablished = false;
report.environmentalSuperiorityEstablished = false;
end

function mustBeNonnegativeScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value < 0
    error("AugmentedHub:InputValue", ...
        "Require an actual finite nonnegative scalar double.");
end
end

function mustBePositiveScalarDouble(value)
mustBeNonnegativeScalarDouble(value);
if value == 0
    error("AugmentedHub:InputValue", ...
        "Require a strictly positive scalar double.");
end
end
