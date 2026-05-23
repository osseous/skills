#requires -Version 5.1
<#
.SYNOPSIS
    Verifies the AngelScript plugin is enabled and reports on the project's AS surface.

.DESCRIPTION
    Walks up to the nearest *.uproject, checks Plugins[] for the Hazelight Angelscript
    plugin, locates the Script/ directory, counts *.as files, and lists discovered
    top-level class declarations. Useful at session start to confirm the AS environment.

.PARAMETER StartDir
    Directory to start searching from. Defaults to PWD.

.PARAMETER Format
    'text' (default) or 'json'.

.EXAMPLE
    powershell -NoProfile -File scripts/detect-angelscript.ps1
.EXAMPLE
    powershell -NoProfile -File scripts/detect-angelscript.ps1 -Format json
#>
param(
    [string]$StartDir = (Get-Location).Path,
    [ValidateSet('text','json')]
    [string]$Format   = 'text'
)

$ErrorActionPreference = 'Stop'

function Find-UProject {
    param([string]$From)
    $dir = (Resolve-Path $From).Path
    while ($true) {
        $u = Get-ChildItem -LiteralPath $dir -Filter *.uproject -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($u) { return $u }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { return $null }
        $dir = $parent
    }
}

$uproj = Find-UProject -From $StartDir
if (-not $uproj) {
    Write-Error "No *.uproject found searching upward from '$StartDir'."
    exit 1
}
$projRoot = $uproj.Directory.FullName
$projData = Get-Content -LiteralPath $uproj.FullName -Raw | ConvertFrom-Json

$plugins = @()
if ($projData.Plugins) { $plugins = @($projData.Plugins) }
$asPlugin = $plugins | Where-Object {
    ($_.Name -match 'Angelscript') -and ($_.Enabled -ne $false)
} | Select-Object -First 1

$scriptDir = Join-Path $projRoot 'Script'
$hasScriptDir = Test-Path $scriptDir

$asFiles = @()
if ($hasScriptDir) {
    $asFiles = Get-ChildItem -LiteralPath $scriptDir -Recurse -Filter *.as -File -ErrorAction SilentlyContinue
}

# Discover top-level class declarations
$classes = New-Object System.Collections.Generic.List[object]
foreach ($f in $asFiles) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    $lineNum = 0
    foreach ($l in $lines) {
        $lineNum++
        # naive class/struct match
        if ($l -match '^\s*(?:UCLASS\([^\)]*\)\s*)?class\s+([UAFEIS][A-Z][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Za-z0-9_]*)') {
            $classes.Add([PSCustomObject]@{
                Name   = $matches[1]
                Parent = $matches[2]
                File   = $f.FullName
                Line   = $lineNum
            })
            break  # first class per file is enough for the summary
        }
        elseif ($l -match '^\s*(?:USTRUCT\([^\)]*\)\s*)?struct\s+(F[A-Za-z0-9_]*)') {
            $classes.Add([PSCustomObject]@{
                Name   = $matches[1]
                Parent = '(struct)'
                File   = $f.FullName
                Line   = $lineNum
            })
            break
        }
    }
}

$result = [PSCustomObject]@{
    ProjectName        = $uproj.BaseName
    ProjectRoot        = $projRoot
    UProject           = $uproj.FullName
    AngelscriptPlugin  = if ($asPlugin) { $asPlugin.Name } else { $null }
    PluginEnabled      = [bool]$asPlugin
    ScriptDir          = if ($hasScriptDir) { $scriptDir } else { $null }
    AsFileCount        = $asFiles.Count
    TopLevelTypes      = $classes
    NextStep           = if (-not $asPlugin) {
        "Add the Angelscript plugin to the uproject Plugins[] array, or install the Hazelight UnrealEngine-Angelscript fork."
    } elseif (-not $hasScriptDir) {
        "Create a Script/ directory at the project root."
    } elseif ($asFiles.Count -eq 0) {
        "Script/ exists but no .as files found. Add a starter file or check the watch path."
    } else {
        "Project ready. Run the editor and grep LogAngelscript via read-ue-logs to confirm scripts loaded."
    }
}

if ($Format -eq 'json') {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "Project:          $($result.ProjectName)"
    Write-Output "Root:             $($result.ProjectRoot)"
    Write-Output "AS plugin:        $(if ($result.AngelscriptPlugin) { $result.AngelscriptPlugin + ' (enabled)' } else { 'NOT FOUND' })"
    Write-Output "Script dir:       $(if ($result.ScriptDir) { $result.ScriptDir } else { '(missing)' })"
    Write-Output ".as file count:   $($result.AsFileCount)"
    Write-Output "Top-level types:  $($classes.Count) found"
    foreach ($c in ($classes | Select-Object -First 25)) {
        Write-Output ("  {0} : {1}    [{2}:{3}]" -f $c.Name, $c.Parent, $c.File, $c.Line)
    }
    if ($classes.Count -gt 25) { Write-Output "  ... (+$($classes.Count - 25) more)" }
    Write-Output ""
    Write-Output "Next step: $($result.NextStep)"
}
