classdef ResearchAuthorizationGate < handle
    % Serialized research model; no audio, network, or device adapter.
    % The caller must provide the independently authorized control channel.
    %
    % Attribution:
    % bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
    % Credit metadata only; not consent or operating authority.

    properties (Access = private)
        Enabled = false
        Cancelled = true
        Destination = ""
        Revision = 0
        CandidateRevision = NaN
        CandidateDestination = ""
        CandidatePending = false
    end

    methods
        function control(obj, action, destination)
            arguments
                obj
                action {mustBeA(action,"string")}
                destination {mustBeA(destination,"string")} = ""
            end

            if ~isscalar(action) || ismissing(action) || ...
                    ~isscalar(destination) || ismissing(destination)
                error("AugmentedHub:ControlInput", ...
                    "Action and destination must be nonmissing strings.");
            end

            allowed = ["enable","disable","cancel","clear_cancel", ...
                "allow_destination","revoke_destination"];

            if ~any(action == allowed)
                error("AugmentedHub:ControlAction", ...
                    "Unknown control action.");
            end

            if action == "allow_destination" && strlength(destination) == 0
                error("AugmentedHub:Destination", ...
                    "A nonempty destination is required.");
            end

            if obj.Revision >= flintmax
                error("AugmentedHub:RevisionExhausted", ...
                    "No further exact revision increments are available.");
            end

            obj.Revision = obj.Revision + 1;
            obj.CandidatePending = false;
            obj.CandidateRevision = NaN;
            obj.CandidateDestination = "";

            switch action
                case "enable"
                    obj.Enabled = true;
                case "disable"
                    obj.Enabled = false;
                case "cancel"
                    obj.Cancelled = true;
                case "clear_cancel"
                    obj.Cancelled = false;
                case "allow_destination"
                    obj.Destination = destination;
                case "revoke_destination"
                    obj.Destination = "";
            end
        end

        function prepare(obj, destination)
            arguments
                obj
                destination {mustBeA(destination,"string")}
            end

            if ~isscalar(destination) || ismissing(destination) || ...
                    strlength(destination) == 0
                error("AugmentedHub:Destination", ...
                    "Supply a nonempty destination string.");
            end

            obj.CandidateRevision = obj.Revision;
            obj.CandidateDestination = destination;
            obj.CandidatePending = true;
        end

        function decision = commit(obj)
            permitted = obj.CandidatePending && ...
                obj.Enabled && ~obj.Cancelled && ...
                strlength(obj.Destination) > 0 && ...
                obj.CandidateDestination == obj.Destination && ...
                obj.CandidateRevision == obj.Revision;

            decision = struct( ...
                "permittedByModel", permitted, ...
                "revision", obj.Revision, ...
                "physicalOutputPerformed", false);

            obj.CandidatePending = false;
            obj.CandidateRevision = NaN;
            obj.CandidateDestination = "";
        end
    end
end
