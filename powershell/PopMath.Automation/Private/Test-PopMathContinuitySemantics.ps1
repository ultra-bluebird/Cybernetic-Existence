function Get-PopMathRequirementKinds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Expression
    )

    $kinds = [System.Collections.Generic.List[string]]::new()

    if ($null -ne $Expression.requirement) {
        $kind = [string]$Expression.requirement.kind

        if (-not [string]::IsNullOrWhiteSpace($kind)) {
            $kinds.Add($kind)
        }

        return @($kinds)
    }

    foreach ($child in @($Expression.all)) {
        foreach ($kind in Get-PopMathRequirementKinds -Expression $child) {
            $kinds.Add($kind)
        }
    }

    foreach ($child in @($Expression.any)) {
        foreach ($kind in Get-PopMathRequirementKinds -Expression $child) {
            $kinds.Add($kind)
        }
    }

    @($kinds | Sort-Object -Unique)
}

function Test-PopMathContinuitySemantics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Scenario
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $continuity = $Scenario.payload.continuity

    if ($null -eq $continuity) {
        $errors.Add("Property 'payload.continuity' is required.")
        return @($errors)
    }

    $requestedWindow = $continuity.requested_window

    if ($null -eq $requestedWindow) {
        $errors.Add("Property 'payload.continuity.requested_window' is required.")
    }
    elseif (
        $requestedWindow.end_seconds_since_epoch `
        -le $requestedWindow.start_seconds_since_epoch
    ) {
        $errors.Add(
            "Property 'payload.continuity.requested_window.end_seconds_since_epoch' must be greater than start_seconds_since_epoch."
        )
    }

    $requirements = $continuity.requirements

    if ($null -eq $requirements) {
        $errors.Add("Property 'payload.continuity.requirements' is required.")
        return @($errors)
    }

    $requirementKinds = @(
        Get-PopMathRequirementKinds -Expression $requirements
    )

    if ($requirementKinds.Count -eq 0) {
        $errors.Add(
            "Property 'payload.continuity.requirements' must contain at least one capability requirement."
        )
    }

    $windowIndex = 0

    foreach ($capabilityWindow in @($continuity.capability_windows)) {
        $kind = [string]$capabilityWindow.kind

        if ($requirementKinds -notcontains $kind) {
            $errors.Add(
                "Property 'payload.continuity.capability_windows[$windowIndex].kind' has no matching requirement kind: $kind."
            )
        }

        $window = $capabilityWindow.window

        if ($null -eq $window) {
            $errors.Add(
                "Property 'payload.continuity.capability_windows[$windowIndex].window' is required."
            )
        }
        elseif (
            $window.end_seconds_since_epoch `
            -le $window.start_seconds_since_epoch
        ) {
            $errors.Add(
                "Property 'payload.continuity.capability_windows[$windowIndex].window.end_seconds_since_epoch' must be greater than start_seconds_since_epoch."
            )
        }

        $windowIndex++
    }

    @($errors | Select-Object -Unique)
}
