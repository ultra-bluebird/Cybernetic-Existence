function report = summarize_assistive_cost_ledgers( ...
    costLines, service, currency, priceYear, costDiscountRate, ...
    serviceDiscountRate)
%SUMMARIZE_ASSISTIVE_COST_LEDGERS Offline multi-perspective cost accounting.
% Cost quantities and unit costs must use declared compatible units.
% support_time quantity must be hours if interpreted as supporter hours.
% Categories and resource boundaries require external review.
% Negative costs/credits are excluded from this gross-cost prototype.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    costLines {mustBeA(costLines,"table")}
    service {mustBeA(service,"table")}
    currency {mustBeA(currency,"string")}
    priceYear {mustBeA(priceYear,"double"), mustBeReal, mustBeFinite}
    costDiscountRate {mustBeNonnegativeScalarDouble}
    serviceDiscountRate {mustBeNonnegativeScalarDouble}
end

costRequired = ["alternative","ledger","category","year","quantity","unitCost"];
serviceRequired = ["alternative","year","qualifyingHours"];
ledgers = ["resource","out_of_pocket","payer_payment","support_time"];

if isempty(costLines) || isempty(service) || ...
        ~all(ismember(costRequired,string(costLines.Properties.VariableNames))) || ...
        ~all(ismember(serviceRequired,string(service.Properties.VariableNames)))
    error("AugmentedHub:InputConsistency", ...
        "Supply nonempty cost and service tables with required columns.");
end

mustBeTextColumn(costLines.alternative);
mustBeTextColumn(costLines.ledger);
mustBeTextColumn(costLines.category);
mustBeTextColumn(service.alternative);

if ~isscalar(currency) || ismissing(currency) || strlength(currency) == 0 || ...
        ~isscalar(priceYear) || priceYear < 1 || priceYear ~= fix(priceYear)
    error("AugmentedHub:InputValue", ...
        "Supply a currency label and integer price year.");
end

for name = ["year","quantity","unitCost"]
    mustBeNumericColumn(costLines.(char(name)));
end
for name = ["year","qualifyingHours"]
    mustBeNumericColumn(service.(char(name)));
end

if any(~ismember(costLines.ledger,ledgers)) || ...
        any(costLines.year < 0) || any(costLines.quantity < 0) || ...
        any(costLines.unitCost < 0) || any(service.year < 0) || ...
        any(service.qualifyingHours < 0)
    error("AugmentedHub:InputValue", ...
        "Use declared ledgers and nonnegative times, quantities, and costs.");
end

alternatives = unique(service.alternative,"stable");
if any(~ismember(costLines.alternative,alternatives))
    error("AugmentedHub:InputConsistency", ...
        "Every cost alternative requires a service-accounting entry.");
end

if height(unique(service(:,["alternative","year"]),"rows")) ~= height(service)
    error("AugmentedHub:InputConsistency", ...
        "Service entries must be unique per alternative and time point.");
end

grossCost = costLines.quantity.*costLines.unitCost;
costFactor = exp(-costLines.year*log1p(costDiscountRate));
serviceFactor = exp(-service.year*log1p(serviceDiscountRate));

discountedCost = grossCost.*costFactor;
discountedService = service.qualifyingHours.*serviceFactor;

if any(~isfinite(grossCost)) || any(~isfinite(discountedCost)) || ...
        any(~isfinite(discountedService))
    error("AugmentedHub:NumericalRange", ...
        "Cost or service arithmetic exceeded finite range.");
end

rows = cell(numel(alternatives)*numel(ledgers),8);
position = 0;

for alternativeIndex = 1:numel(alternatives)
    alternative = alternatives(alternativeIndex);
    serviceRows = service.alternative == alternative;
    hours = sum(service.qualifyingHours(serviceRows));
    pvHours = sum(discountedService(serviceRows));

    for ledger = ledgers
        position = position+1;
        selected = costLines.alternative == alternative & ...
            costLines.ledger == ledger;
        lineCount = sum(selected);
        total = sum(grossCost(selected));
        pvTotal = sum(discountedCost(selected));
        perHour = NaN;

        if lineCount > 0 && pvHours > 0
            perHour = pvTotal/pvHours;
        end

        % An absent ledger is unavailable, not evidence of zero cost.
        if lineCount == 0
            total = NaN;
            pvTotal = NaN;
        end

        rows(position,:) = {alternative,ledger,lineCount, ...
            total,pvTotal,hours,pvHours,perHour};
    end
end

report = struct();
report.mode = "offline-multiple-cost-ledger-summary";
report.currency = currency;
report.priceYear = priceYear;
report.costDiscountRate = costDiscountRate;
report.serviceDiscountRate = serviceDiscountRate;
report.ledgersMayBeAddedTogether = false;
report.resourceBoundaryValidated = false;
report.unitCostsValidated = false;
report.qualifyingServiceDefinitionValidated = false;
report.costEffectivenessEstablished = false;
report.affordabilityEstablished = false;

report.summary = cell2table(rows,"VariableNames", ...
    ["alternative","ledger","costLineCount","undiscountedCost", ...
    "presentValueCost","qualifyingHours","discountedQualifyingHours", ...
    "presentValueCostPerDiscountedQualifyingHour"]);
end

function mustBeNonnegativeScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value < 0
    error("AugmentedHub:InputValue", ...
        "Require an actual finite nonnegative scalar double.");
end
end

function mustBeTextColumn(value)
if ~isa(value,"string") || size(value,2) ~= 1 || ...
        any(ismissing(value)) || any(strlength(value) == 0)
    error("AugmentedHub:InputType", ...
        "Text columns must contain nonempty string entries.");
end
end

function mustBeNumericColumn(value)
if ~isa(value,"double") || ~isreal(value) || ...
        size(value,2) ~= 1 || any(~isfinite(value))
    error("AugmentedHub:InputType", ...
        "Numerical columns must contain finite real doubles.");
end
end
