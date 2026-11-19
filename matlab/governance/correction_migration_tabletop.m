function report = correction_migration_tabletop()
%CORRECTION_MIGRATION_TABLETOP Synthetic policy model, not sanitization.
% Run:
%   report = correction_migration_tabletop();
%
% All evidence flags below are synthetic declarations.
% No cryptographic authentication or physical deletion is performed.

    attempts = 1e6;
    witnessBits = [128; 256];
    guessBounds = min(1, attempts .* 2.^(-witnessBits));

    report.witnessMath = table( ...
        witnessBits, guessBounds, ...
        'VariableNames', {'WitnessBits', 'GuessBound'});

    base = struct( ...
        'authorized', true, ...
        'inventoryReviewed', true, ...
        'methodApproved', true, ...
        'locationsVerified', true(1, 4), ...
        'witnessDispositionVerified', true, ...
        'retainedMetadataReviewed', true, ...
        'prohibitedPersonalContentRetained', false);

    complete = deletionGate(base);

    missingBackup = base;
    missingBackup.locationsVerified(4) = false;
    backupResult = deletionGate(missingBackup);

    publicValue = base;
    publicValue.prohibitedPersonalContentRetained = true;
    publicResult = deletionGate(publicValue);

    witnessUnknown = base;
    witnessUnknown.witnessDispositionVerified = false;
    witnessResult = deletionGate(witnessUnknown);

    emptyInventory = base;
    emptyInventory.locationsVerified = false(1, 0);
    emptyResult = deletionGate(emptyInventory);

    assert(complete.scopedPolicyEvidenceComplete);
    assert(~backupResult.scopedPolicyEvidenceComplete);
    assert(backupResult.coverage == 0.75);
    assert(~publicResult.scopedPolicyEvidenceComplete);
    assert(~witnessResult.scopedPolicyEvidenceComplete);
    assert(~emptyResult.scopedPolicyEvidenceComplete);
    assert(isnan(emptyResult.coverage));

    caseName = [ ...
        "Complete synthetic evidence"; ...
        "Unverified backup"; ...
        "Prohibited personal content retained"; ...
        "Witness disposition unverified"; ...
        "Empty inventory"];

    coverage = [ ...
        complete.coverage; ...
        backupResult.coverage; ...
        publicResult.coverage; ...
        witnessResult.coverage; ...
        emptyResult.coverage];

    policyComplete = [ ...
        complete.scopedPolicyEvidenceComplete; ...
        backupResult.scopedPolicyEvidenceComplete; ...
        publicResult.scopedPolicyEvidenceComplete; ...
        witnessResult.scopedPolicyEvidenceComplete; ...
        emptyResult.scopedPolicyEvidenceComplete];

    report.deletionCases = table( ...
        caseName, coverage, policyComplete);

    oldContext = context("chain-domain-1", "1", "profile-1");
    newContext = context("chain-domain-2", "2", "profile-2");

    registry = struct();
    registry.historicalContexts = [oldContext, newContext];
    registry.appendContexts = newContext;
    registry.edges = struct( ...
        'from', oldContext, ...
        'to', newContext);

    boundary = struct( ...
        'present', true, ...
        'from', oldContext, ...
        'to', newContext, ...
        'sourceContextVerified', true, ...
        'priorHeadMatched', true, ...
        'transitionLinkVerified', true, ...
        'exactApprovalVerified', true, ...
        'registryRevisionMatched', true);

    validTransition = transitionGate( ...
        oldContext, newContext, boundary, registry);

    absentBoundary = boundary;
    absentBoundary.present = false;
    silentChange = transitionGate( ...
        oldContext, newContext, absentBoundary, registry);

    unapproved = boundary;
    unapproved.exactApprovalVerified = false;
    unapprovedChange = transitionGate( ...
        oldContext, newContext, unapproved, registry);

    unknownContext = context("chain-domain-3", "3", "profile-3");
    unknownChange = transitionGate( ...
        oldContext, unknownContext, boundary, registry);

    oldAppend = transitionGate( ...
        oldContext, oldContext, boundary, registry);

    currentAppend = transitionGate( ...
        newContext, newContext, boundary, registry);

    assert(validTransition == "DECLARED_CHECKS_PASS");
    assert(silentChange == "MISSING_TRANSITION");
    assert(unapprovedChange == "TRANSITION_EVIDENCE_INCOMPLETE");
    assert(unknownChange == "TARGET_APPEND_NOT_ALLOWED");
    assert(oldAppend == "TARGET_APPEND_NOT_ALLOWED");
    assert(currentAppend == "SAME_CONTEXT_APPEND_ALLOWED");

    report.migrationCases = table( ...
        ["Explicit permitted transition"; ...
         "Silent context change"; ...
         "Approval absent"; ...
         "Unknown target"; ...
         "Append using retired context"; ...
         "Append using current context"], ...
        [validTransition; silentChange; unapprovedChange; ...
         unknownChange; oldAppend; currentAppend], ...
        'VariableNames', {'Case', 'Status'});

    report.historicalOldContextAllowed = containsContext( ...
        registry.historicalContexts, oldContext);
    assert(report.historicalOldContextAllowed);

    report.syntheticOnly = true;
    report.assertionsDefined = 14;
    report.physicalDeletionVerified = false;
    report.cryptographicVerificationPerformed = false;
    report.externalActionAuthorized = false;
end

function result = deletionGate(evidence)
    requiredFlags = { ...
        'authorized', ...
        'inventoryReviewed', ...
        'methodApproved', ...
        'witnessDispositionVerified', ...
        'retainedMetadataReviewed', ...
        'prohibitedPersonalContentRetained'};

    if ~isstruct(evidence) || ~isscalar(evidence)
        error('Input must be a scalar evidence structure.');
    end

    for k = 1:numel(requiredFlags)
        name = requiredFlags{k};
        if ~isfield(evidence, name) || ...
                ~islogical(evidence.(name)) || ...
                ~isscalar(evidence.(name))
            error('Evidence flags must be scalar logical values.');
        end
    end

    if ~isfield(evidence, 'locationsVerified') || ...
            ~islogical(evidence.locationsVerified) || ...
            (~isvector(evidence.locationsVerified) && ...
             ~isempty(evidence.locationsVerified))
        error('locationsVerified must be a logical vector.');
    end

    count = numel(evidence.locationsVerified);

    if count == 0
        coverage = NaN;
        allLocationsVerified = false;
    else
        coverage = nnz(evidence.locationsVerified) / count;
        allLocationsVerified = all(evidence.locationsVerified(:));
    end

    result = struct();
    result.coverage = coverage;
    result.scopedPolicyEvidenceComplete = ...
        evidence.authorized && ...
        evidence.inventoryReviewed && ...
        evidence.methodApproved && ...
        allLocationsVerified && ...
        evidence.witnessDispositionVerified && ...
        evidence.retainedMetadataReviewed && ...
        ~evidence.prohibitedPersonalContentRetained;

    result.physicalDeletionVerified = false;
    result.externalActionAuthorized = false;
end

function value = context(domain, schema, profile)
    value = struct( ...
        'domain', domain, ...
        'schema', schema, ...
        'profile', profile);
end

function matched = sameContext(a, b)
    matched = isequal(a.domain, b.domain) && ...
        isequal(a.schema, b.schema) && ...
        isequal(a.profile, b.profile);
end

function found = containsContext(contexts, candidate)
    found = false;
    for k = 1:numel(contexts)
        if sameContext(contexts(k), candidate)
            found = true;
            return;
        end
    end
end

function status = transitionGate(source, target, boundary, registry)
    if ~containsContext(registry.historicalContexts, source)
        status = "SOURCE_VERIFY_NOT_ALLOWED";
        return;
    end

    if ~containsContext(registry.appendContexts, target)
        status = "TARGET_APPEND_NOT_ALLOWED";
        return;
    end

    if sameContext(source, target)
        status = "SAME_CONTEXT_APPEND_ALLOWED";
        return;
    end

    if ~boundary.present
        status = "MISSING_TRANSITION";
        return;
    end

    edgeAllowed = false;
    for k = 1:numel(registry.edges)
        edge = registry.edges(k);
        if sameContext(edge.from, source) && ...
                sameContext(edge.to, target)
            edgeAllowed = true;
            break;
        end
    end

    if ~edgeAllowed
        status = "TRANSITION_EDGE_NOT_ALLOWED";
        return;
    end

    if ~sameContext(boundary.from, source) || ...
            ~sameContext(boundary.to, target)
        status = "TRANSITION_CONTEXT_MISMATCH";
        return;
    end

    checks = [ ...
        boundary.sourceContextVerified, ...
        boundary.priorHeadMatched, ...
        boundary.transitionLinkVerified, ...
        boundary.exactApprovalVerified, ...
        boundary.registryRevisionMatched];

    if ~islogical(checks) || ~all(checks)
        status = "TRANSITION_EVIDENCE_INCOMPLETE";
        return;
    end

    status = "DECLARED_CHECKS_PASS";
end
