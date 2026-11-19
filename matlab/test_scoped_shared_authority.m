function test_scoped_shared_authority()
% Synthetic task labels; no message transmission or device access.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

policy(1) = struct( ...
    "name","format_preview", ...
    "destination","local_preview", ...
    "mode","delegated_execute");

policy(2) = struct( ...
    "name","send_message", ...
    "destination","reviewed_destination", ...
    "mode","confirm_each");

policy(3) = struct( ...
    "name","suggest_wording", ...
    "destination","local_preview", ...
    "mode","suggest_only");

gate = ScopedSharedAuthority(policy);

gate.delegate("format_preview",100,0);
gate.prepare("format_preview");
d = gate.commitDecision(1);
assert(~d.permittedByModel);
assert(d.reason == "paused");

gate.resume();
gate.prepare("format_preview");
d = gate.commitDecision(2);
assert(d.permittedByModel);

gate.delegate("send_message",100,2);
gate.prepare("send_message");
d = gate.commitDecision(3);
assert(~d.permittedByModel);
assert(d.reason == "action_confirmation_required");

gate.prepare("send_message");
gate.confirmPending();
d = gate.commitDecision(4);
assert(d.permittedByModel);

gate.prepare("send_message");
gate.confirmPending();
gate.pause();
gate.resume();
d = gate.commitDecision(5);
assert(~d.permittedByModel);

gate.delegate("suggest_wording",100,5);
gate.prepare("suggest_wording");
gate.confirmPending();
d = gate.commitDecision(6);
assert(~d.permittedByModel);

gate.prepare("format_preview");
d = gate.commitDecision(100);
assert(~d.permittedByModel);

gate.delegate("format_preview",200,100);
gate.revoke("format_preview");
gate.prepare("format_preview");
d = gate.commitDecision(101);
assert(~d.permittedByModel);
end
