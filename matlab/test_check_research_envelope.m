function test_check_research_envelope()
% Dimensionless synthetic constraints only.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

e = struct();
e.quantityNames = ["feature_a";"feature_b"];
e.quantityUnits = ["dimensionless";"dimensionless"];
e.lower = [0;0];
e.upper = [1;1];
e.A = [1,1;-1,1];
e.b = [1.2;0.5];
e.context = struct("studyConfiguration","synthetic_fixture");
e.validFromSeconds = 0;
e.expiresSeconds = 100;

names = e.quantityNames;
units = e.quantityUnits;
context = e.context;

inside = check_research_envelope( ...
    [0.2;0.2],[0.4;0.5],names,units,e,context,10);
assert(inside.mathematicallyWithinSuppliedEnvelope);
assert(abs(inside.worstCaseLinearValues(2)-0.3) < 1e-12);

coupledViolation = check_research_envelope( ...
    [0.5;0.5],[0.7;0.7],names,units,e,context,10);
assert(all(coupledViolation.boxSatisfied));
assert(~coupledViolation.mathematicallyWithinSuppliedEnvelope);

boxViolation = check_research_envelope( ...
    [0.2;0.2],[1.1;0.3],names,units,e,context,10);
assert(~all(boxViolation.boxSatisfied));

expired = check_research_envelope( ...
    [0.2;0.2],[0.4;0.5],names,units,e,context,100);
assert(~expired.envelopeTimeCurrent);

wrongContext = struct("studyConfiguration","different_fixture");
mismatch = check_research_envelope( ...
    [0.2;0.2],[0.4;0.5],names,units,e,wrongContext,10);
assert(~mismatch.contextMatches);

reordered = check_research_envelope( ...
    [0.2;0.2],[0.4;0.5],flipud(names),units,e,context,10);
assert(~reordered.quantityNamesMatch);

assert(~inside.clinicalSafetyEstablished);
assert(~inside.operationalAuthorizationEstablished);
end
