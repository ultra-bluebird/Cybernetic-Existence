$semanticErrors = [System.Collections.Generic.List[string]]::new()

try {
    $scenarioObject = $scenarioJson |
        ConvertFrom-Json `
            -Depth 100 `
            -ErrorAction Stop

    if ($null -ne $scenarioObject.payload.continuity) {
        foreach ($semanticError in @(
            Test-PopMathContinuitySemantics -Scenario $scenarioObject
        )) {
            $semanticErrors.Add($semanticError)
        }
    }
}
catch {
    $semanticErrors.Add(
        "Continuity semantic validation could not complete: $($_.Exception.Message)"
    )
}

foreach ($semanticError in $semanticErrors) {
    $errors.Add($semanticError)
}

$isValid = $isValid -and ($semanticErrors.Count -eq 0)
