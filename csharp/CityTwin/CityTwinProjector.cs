using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;

namespace AugmentedHub.CityTwin;

public sealed record TelemetryEvent(
    string EventId,
    string AssetId,
    string AssetKind,
    string ObservedAtUtc,
    string Metric,
    double Value,
    string Unit,
    long Sequence,
    string SourceTrust);

public sealed record TwinState(
    string AssetId,
    string AssetKind,
    long Version,
    DateTimeOffset ObservedAtUtc,
    IReadOnlyDictionary<string, double> Metrics,
    bool IsStale,
    string SourceTrust);

public sealed record TwinChange(
    string AssetId,
    long PreviousVersion,
    long CurrentVersion,
    string Reason,
    TwinState State);

public sealed class CityTwinProjector
{
    private readonly ConcurrentDictionary<string, TwinState> _states = new();
    private readonly TimeSpan _maximumTelemetryAge;

    public CityTwinProjector(TimeSpan maximumTelemetryAge)
    {
        if (maximumTelemetryAge <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(
                nameof(maximumTelemetryAge),
                "Maximum telemetry age must be positive.");
        }

        _maximumTelemetryAge = maximumTelemetryAge;
    }

    public bool TryApply(
        TelemetryEvent telemetry,
        DateTimeOffset receivedAtUtc,
        out TwinChange? change,
        out string? rejectionReason)
    {
        change = null;
        rejectionReason = null;

        if (!IsValidIdentifier(telemetry.EventId) ||
            !IsValidIdentifier(telemetry.AssetId) ||
            !IsValidIdentifier(telemetry.AssetKind) ||
            !IsValidIdentifier(telemetry.Metric) ||
            !IsValidIdentifier(telemetry.Unit))
        {
            rejectionReason = "Telemetry has a missing or invalid identifier.";
            return false;
        }

        if (!double.IsFinite(telemetry.Value))
        {
            rejectionReason = "Telemetry value must be finite.";
            return false;
        }

        if (telemetry.Sequence < 0)
        {
            rejectionReason = "Telemetry sequence must be non-negative.";
            return false;
        }

        if (!DateTimeOffset.TryParse(
                telemetry.ObservedAtUtc,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal,
                out var observedAtUtc))
        {
            rejectionReason = "Telemetry timestamp is invalid.";
            return false;
        }

        if (observedAtUtc > receivedAtUtc.AddMinutes(5))
        {
            rejectionReason = "Telemetry timestamp is excessively in the future.";
            return false;
        }

        while (true)
        {
            if (_states.TryGetValue(telemetry.AssetId, out var current))
            {
                if (telemetry.Sequence <= current.Version)
                {
                    rejectionReason = "Out-of-order or duplicate telemetry was ignored.";
                    return false;
                }

                var metrics = new Dictionary<string, double>(
                    current.Metrics,
                    StringComparer.Ordinal)
                {
                    [telemetry.Metric] = telemetry.Value
                };

                var proposed = new TwinState(
                    telemetry.AssetId,
                    telemetry.AssetKind,
                    telemetry.Sequence,
                    observedAtUtc,
                    metrics,
                    receivedAtUtc - observedAtUtc > _maximumTelemetryAge,
                    telemetry.SourceTrust);

                if (_states.TryUpdate(telemetry.AssetId, proposed, current))
                {
                    change = new TwinChange(
                        telemetry.AssetId,
                        current.Version,
                        proposed.Version,
                        $"Updated metric '{telemetry.Metric}'.",
                        proposed);
                    return true;
                }

                continue;
            }

            var initialMetrics = new Dictionary<string, double>(
                StringComparer.Ordinal)
            {
                [telemetry.Metric] = telemetry.Value
            };

            var initial = new TwinState(
                telemetry.AssetId,
                telemetry.AssetKind,
                telemetry.Sequence,
                observedAtUtc,
                initialMetrics,
                receivedAtUtc - observedAtUtc > _maximumTelemetryAge,
                telemetry.SourceTrust);

            if (_states.TryAdd(telemetry.AssetId, initial))
            {
                change = new TwinChange(
                    telemetry.AssetId,
                    -1,
                    initial.Version,
                    "Created twin state from first accepted telemetry.",
                    initial);
                return true;
            }
        }
    }

    public bool TryGetState(string assetId, out TwinState? state)
    {
        return _states.TryGetValue(assetId, out state);
    }

    private static bool IsValidIdentifier(string value)
    {
        return !string.IsNullOrWhiteSpace(value) &&
               value.Length <= 160;
    }
}
