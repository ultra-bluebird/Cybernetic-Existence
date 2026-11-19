classdef ScopedSharedAuthority < handle
    % Serialized research model; no physical output or external actions.
    % Policy fields per task:
    % name, destination, mode
    % mode: "suggest_only", "delegated_execute", "confirm_each"
    %
    % Attribution:
    % bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
    % Credit/workstream metadata only; not consent or authority evidence.

    properties (Access = private)
        Policy
        Active
        Expires
        Paused = true
        Epoch = 0
        Pending = struct([])
    end

    methods
        function obj = ScopedSharedAuthority(policy)
            if ~isstruct(policy) || isempty(policy) || ~isvector(policy) || ...
                    ~all(isfield(policy,{"name","destination","mode"}))
                error("AugmentedHub:InputShape","Invalid task policy.");
            end

            names = strings(numel(policy),1);
            for index = 1:numel(policy)
                fields = ["name","destination","mode"];
                for field = fields
                    value = policy(index).(char(field));
                    if ~isa(value,"string") || ~isscalar(value) || ...
                            ismissing(value) || strlength(value) == 0
                        error("AugmentedHub:InputValue", ...
                            "Policy fields must be nonempty string scalars.");
                    end
                end

                if ~any(policy(index).mode == ...
                        ["suggest_only","delegated_execute","confirm_each"])
                    error("AugmentedHub:InputValue","Unknown authority mode.");
                end
                names(index) = policy(index).name;
            end

            if numel(unique(names)) ~= numel(names)
                error("AugmentedHub:InputValue","Task names must be unique.");
            end

            obj.Policy = policy(:);
            obj.Active = false(numel(policy),1);
            obj.Expires = -Inf(numel(policy),1);
        end

        function delegate(obj,task,expiresAt,nowSeconds)
            index = obj.findTask(task);
            obj.checkTime(expiresAt);
            obj.checkTime(nowSeconds);

            if expiresAt <= nowSeconds
                error("AugmentedHub:InputValue", ...
                    "Delegation expiry must be later than current time.");
            end

            obj.advanceEpoch();
            obj.Active(index) = true;
            obj.Expires(index) = expiresAt;
        end

        function revoke(obj,task)
            index = obj.findTask(task);
            obj.advanceEpoch();
            obj.Active(index) = false;
            obj.Expires(index) = -Inf;
        end

        function pause(obj)
            obj.advanceEpoch();
            obj.Paused = true;
        end

        function resume(obj)
            obj.advanceEpoch();
            obj.Paused = false;
        end

        function prepare(obj,task)
            index = obj.findTask(task);
            obj.Pending = struct( ...
                "taskPosition",index, ...
                "epoch",obj.Epoch, ...
                "confirmed",false);
        end

        function confirmPending(obj)
            if isempty(obj.Pending)
                error("AugmentedHub:NoCandidate", ...
                    "There is no pending candidate to confirm.");
            end
            obj.Pending.confirmed = true;
        end

        function decision = commitDecision(obj,nowSeconds)
            obj.checkTime(nowSeconds);
            permitted = false;
            reason = "no_pending_candidate";
            destination = "";

            if ~isempty(obj.Pending)
                index = obj.Pending.taskPosition;
                p = obj.Policy(index);
                destination = p.destination;

                if obj.Paused
                    reason = "paused";
                elseif obj.Pending.epoch ~= obj.Epoch
                    reason = "stale_candidate";
                elseif ~obj.Active(index) || nowSeconds >= obj.Expires(index)
                    reason = "delegation_unavailable";
                elseif p.mode == "suggest_only"
                    reason = "suggestion_has_no_execution_authority";
                elseif p.mode == "confirm_each" && ~obj.Pending.confirmed
                    reason = "action_confirmation_required";
                else
                    permitted = true;
                    reason = "within_supplied_delegation_model";
                end
            end

            decision = struct( ...
                "permittedByModel",permitted, ...
                "reason",reason, ...
                "destination",destination, ...
                "epoch",obj.Epoch, ...
                "scope","local_policy_decision_only");

            obj.Pending = struct([]);
        end
    end

    methods (Access = private)
        function index = findTask(obj,task)
            if ~isa(task,"string") || ~isscalar(task) || ismissing(task)
                error("AugmentedHub:InputType", ...
                    "Task must be a nonmissing string scalar.");
            end

            index = find(arrayfun(@(p) p.name == task,obj.Policy),1);
            if isempty(index)
                error("AugmentedHub:UnknownTask","Task is not in the policy.");
            end
        end

        function advanceEpoch(obj)
            if obj.Epoch >= flintmax
                error("AugmentedHub:EpochExhausted", ...
                    "No further exact epoch increments are available.");
            end
            obj.Epoch = obj.Epoch+1;
            obj.Pending = struct([]);
        end

        function checkTime(~,value)
            if ~isa(value,"double") || ~isscalar(value) || ...
                    ~isreal(value) || ~isfinite(value)
                error("AugmentedHub:InputValue", ...
                    "Time must be an actual finite scalar double.");
            end
        end
    end
end
