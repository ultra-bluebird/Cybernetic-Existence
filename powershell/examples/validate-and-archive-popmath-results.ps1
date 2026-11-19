$repositoryRoot = (Resolve-Path "$PSScriptRoot/../..").Path

Import-Module `
    (Join-Path $repositoryRoot 'powershell/PopMath.Archive/PopMath.Archive.psd1') `
    -Force

$resultPath = Join-Path $repositoryRoot 'artifacts/continuity-corridor.json'
$archiveRoot = Join-Path $repositoryRoot 'artifacts/archive'

$archiveRecord = Save-PopMathResult `
    -ResultPath $resultPath `
    -ArchiveRoot $archiveRoot

$archiveRecord | Format-List

Get-PopMathArchivedResult `
    -Digest $archiveRecord.Digest `
    -ArchiveRoot $archiveRoot |
    Select-Object Digest, ScenarioId, CrateVersion, ArchivePath |
    Format-Table -AutoSize
