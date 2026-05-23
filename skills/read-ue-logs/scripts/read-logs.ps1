#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Read and filter Unreal Engine log output from disk.

.DESCRIPTION
    Reads the on-disk UE log files under Saved/Logs/ and merges entries across
    every concurrently-active project log (<Project>.log, <Project>_2.log, ...).
    Supports filtering by category, verbosity, and free-text/regex search.

    The project name is auto-detected by walking up from the script location
    until a *.uproject is found; the log filename then matches that basename.
    Override with -ProjectName for unusual setups (renamed logs, etc.).

    Works whether the editor is open or closed; no port, no proxy, no plugin.

.NOTES
    Skill: read-ue-logs
    Spec:  https://skills.sh
#>
[CmdletBinding()]
param(
    [int]$Tail = 50,
    [string]$Category,
    [string]$Verbosity,
    [string]$Search,
    [string]$LogFile,
    [int]$RecentMinutes = 10,
    [string]$Source,
    [string]$ProjectName,
    [ValidateSet('text', 'json')]
    [string]$Format = 'text',
    [switch]$Help
)

if ($Help) {
@'
read-logs.ps1 - Read and filter Unreal Engine logs.

USAGE
    powershell -File read-logs.ps1 [-Tail <int>] [-Category <string>]
        [-Verbosity <string>] [-Search <regex>] [-LogFile <path>|all]
        [-RecentMinutes <int>] [-Source <name>] [-ProjectName <name>]
        [-Format text|json] [-Help]

    (Use `pwsh -File ...` instead of `powershell -File ...` if PowerShell 7+
     is installed. Both work; the script is compatible with both editions.)

FLAGS
    -Tail <int>            Last N matching lines after filtering. Default: 50.
    -Category <string>     Case-insensitive substring match on log category
                           (e.g. "LogTemp", "LogBlueprint", "LogRenderer").
    -Verbosity <string>    Exact match: Error | Warning | Display | Verbose | VeryVerbose.
    -Search <regex>        Regex match against the message body.
    -LogFile <path>        Explicit log file. Use "all" to scan rotated backups too.
                           Default: auto-discover active project logs.
    -RecentMinutes <int>   Auto-discovery window. Default: 10. Only includes log
                           files modified within this many minutes. If none match,
                           falls back to the single most-recent log.
    -Source <name>         Filter the merged stream by file basename (e.g.
                           "MyProject_2") to isolate one client.
    -ProjectName <name>    Override project name. Default: derived from the
                           nearest *.uproject by walking up from this script.
    -Format <text|json>    Output format. Default: text. JSON emits one object
                           per line with source/timestamp/category/verbosity/message.
    -Help                  Show this help.

EXAMPLES
    powershell -File read-logs.ps1
        Last 50 entries across every project log touched in the past 10 minutes.

    powershell -File read-logs.ps1 -Verbosity Error -Tail 100
        Last 100 errors.

    powershell -File read-logs.ps1 -Category LogBlueprint -Tail 100
        Last 100 Blueprint entries.

    powershell -File read-logs.ps1 -Search "MyActor"
        Anything mentioning "MyActor" in the message body.

    powershell -File read-logs.ps1 -Source MyProject_2
        Only entries from the second concurrent instance.

    powershell -File read-logs.ps1 -LogFile all -Verbosity Error
        Errors across all logs including rotated backups.

    powershell -File read-logs.ps1 -Format json -Tail 20
        JSON output for downstream tooling.
'@ | Write-Output
    exit 0
}

function Find-UProject {
    param([string]$Start)
    $dir = Get-Item -LiteralPath $Start -ErrorAction SilentlyContinue
    while ($dir) {
        $match = Get-ChildItem -LiteralPath $dir.FullName -Filter '*.uproject' -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($match) {
            return [pscustomobject]@{
                Root = $dir.FullName
                Name = [System.IO.Path]::GetFileNameWithoutExtension($match.Name)
            }
        }
        $dir = $dir.Parent
    }
    return $null
}

function ConvertFrom-LogTimestamp {
    param([string]$Raw)
    # UE format: YYYY.MM.DD-HH.MM.SS:mmm
    if ($Raw -match '^(\d{4})\.(\d{2})\.(\d{2})-(\d{2})\.(\d{2})\.(\d{2}):(\d{3})$') {
        return [datetime]::new(
            [int]$Matches[1], [int]$Matches[2], [int]$Matches[3],
            [int]$Matches[4], [int]$Matches[5], [int]$Matches[6],
            [int]$Matches[7]
        )
    }
    return [datetime]::MinValue
}

$projectInfo = Find-UProject -Start $PSScriptRoot
if (-not $projectInfo) {
    Write-Error "Could not locate any *.uproject by walking up from $PSScriptRoot"
    exit 1
}

$projectRoot = $projectInfo.Root
if (-not $ProjectName) { $ProjectName = $projectInfo.Name }

$logsDir = Join-Path $projectRoot 'Saved\Logs'
if (-not (Test-Path -LiteralPath $logsDir)) {
    Write-Error "Logs directory not found: $logsDir"
    exit 1
}

# Build project-specific patterns/regex from the resolved name.
$escapedName = [regex]::Escape($ProjectName)
$activeRe   = "^$escapedName(_\d+)?\.log$"
$allFilter  = "$ProjectName*.log"

# Resolve target log file(s)
$targets = @()
if ($LogFile) {
    if ($LogFile -ieq 'all') {
        $targets = @(Get-ChildItem -Path $logsDir -Filter $allFilter -File |
            Sort-Object LastWriteTime)
    }
    else {
        $resolved = if ([System.IO.Path]::IsPathRooted($LogFile)) {
            $LogFile
        }
        else {
            Join-Path $projectRoot $LogFile
        }
        if (-not (Test-Path -LiteralPath $resolved)) {
            Write-Error "Log file not found: $resolved"
            exit 1
        }
        $targets = @(Get-Item -LiteralPath $resolved)
    }
}
else {
    # Auto-discovery: active project logs only (exclude -backup-*)
    $candidates = @(Get-ChildItem -Path $logsDir -File |
        Where-Object { $_.Name -match $activeRe })

    if ($candidates.Count -eq 0) {
        Write-Error "No $ProjectName*.log files found in $logsDir"
        exit 1
    }

    $cutoff = (Get-Date).AddMinutes(-$RecentMinutes)
    $recent = @($candidates | Where-Object { $_.LastWriteTime -ge $cutoff })

    if ($recent.Count -gt 0) {
        $targets = @($recent | Sort-Object LastWriteTime)
    }
    else {
        $latest = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $targets = @($latest)
    }
}

# Parse all entries from all target files, tagging with source filename.
# Lines that don't match the prefix pattern (continuations, banners) inherit
# the timestamp of the previous parsed entry within the same file so they
# sort alongside it during the cross-file merge.
$lineRe = [regex]'^\[(?<ts>[0-9.\-:]+)\]\[\s*(?<thread>\d+)\](?<cat>[A-Za-z][A-Za-z0-9_]*):\s*(?:(?<verb>Error|Warning|Display|Verbose|VeryVerbose):\s*)?(?<msg>.*)$'

$entries = [System.Collections.Generic.List[psobject]]::new()
foreach ($file in $targets) {
    # NOTE: PowerShell variables are case-insensitive — must not name this $source
    # because it would shadow the script param $Source used by the filter below.
    $srcName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $lineNo = 0
    $lastTs = [datetime]::MinValue
    $lastTsRaw = ''
    foreach ($chunk in (Get-Content -LiteralPath $file.FullName -ReadCount 1000)) {
        foreach ($line in $chunk) {
            $lineNo++
            $m = $lineRe.Match($line)
            if ($m.Success) {
                $lastTs = ConvertFrom-LogTimestamp $m.Groups['ts'].Value
                $lastTsRaw = $m.Groups['ts'].Value
                $verb = if ($m.Groups['verb'].Success) { $m.Groups['verb'].Value } else { 'Display' }
                $entries.Add([pscustomobject]@{
                    Source       = $srcName
                    Line         = $lineNo
                    Timestamp    = $lastTs
                    TimestampRaw = $lastTsRaw
                    Thread       = $m.Groups['thread'].Value
                    Category     = $m.Groups['cat'].Value
                    Verbosity    = $verb
                    Message      = $m.Groups['msg'].Value
                    Raw          = $line
                })
            }
            else {
                $entries.Add([pscustomobject]@{
                    Source       = $srcName
                    Line         = $lineNo
                    Timestamp    = $lastTs
                    TimestampRaw = $lastTsRaw
                    Thread       = ''
                    Category     = ''
                    Verbosity    = ''
                    Message      = $line
                    Raw          = $line
                })
            }
        }
    }
}

# Cross-file merge by timestamp; preserve in-file order with line tiebreak.
$stream = $entries | Sort-Object Timestamp, Source, Line

if ($Source)    { $stream = $stream | Where-Object { $_.Source -eq $Source } }
if ($Category)  { $stream = $stream | Where-Object { $_.Category -like "*$Category*" } }
if ($Verbosity) { $stream = $stream | Where-Object { $_.Verbosity -eq $Verbosity } }
if ($Search)    { $stream = $stream | Where-Object { $_.Message -match $Search } }

if ($Tail -gt 0) { $stream = $stream | Select-Object -Last $Tail }

$showSource = ($targets.Count -gt 1)
if ($Format -eq 'json') {
    $stream | ForEach-Object {
        [pscustomobject]@{
            source    = $_.Source
            line      = $_.Line
            timestamp = $_.TimestampRaw
            thread    = $_.Thread
            category  = $_.Category
            verbosity = $_.Verbosity
            message   = $_.Message
        } | ConvertTo-Json -Compress
    }
}
else {
    $stream | ForEach-Object {
        if ($showSource) { "[$($_.Source)] $($_.Raw)" } else { $_.Raw }
    }
}

exit 0
