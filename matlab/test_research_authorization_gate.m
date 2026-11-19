function test_research_authorization_gate()
% Serialized interleaving tests, not a concurrent-runtime proof.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

gate = ResearchAuthorizationGate();

gate.prepare("local_audio");
d = gate.commit();
assert(~d.permittedByModel);

gate.control("allow_destination","local_audio");
gate.control("enable");
gate.prepare("local_audio");
d = gate.commit();
assert(~d.permittedByModel);

gate.control("clear_cancel");
gate.prepare("local_audio");
d = gate.commit();
assert(d.permittedByModel);
assert(~d.physicalOutputPerformed);

d = gate.commit();
assert(~d.permittedByModel);

gate.prepare("local_audio");
gate.control("cancel");
d = gate.commit();
assert(~d.permittedByModel);

gate.control("clear_cancel");
d = gate.commit();
assert(~d.permittedByModel);

gate.prepare("local_audio");
gate.control("revoke_destination");
d = gate.commit();
assert(~d.permittedByModel);

gate.control("allow_destination","local_audio");
gate.prepare("external_transmission");
d = gate.commit();
assert(~d.permittedByModel);

gate.prepare("local_audio");
gate.control("disable");
gate.control("enable");
d = gate.commit();
assert(~d.permittedByModel);
end
