#requires -Version 5.1
<#
.SYNOPSIS
    Search for a UE symbol (UCLASS/USTRUCT/UFUNCTION/typename) across the project
    Source/ and (if available) the resolved engine source tree.

.DESCRIPTION
    Runs two searches:
      1. Project Source/ — fast.
      2. Engine Source/ — opt-in via -IncludeEngine (paths discovered via detect-engine.ps1).

    Prints up to -MaxHits per location with file path + line + context.

.PARAMETER Name
    The symbol to look for. Whole-word match.

.PARAMETER IncludeEngine
    Also search the resolved engine source tree.

.PARAMETER MaxHits
    Cap results per scope. Default 20.

.EXAMPLE
    powershell -NoProfile -File scripts/find-uclass.ps1 -Name UAbilitySystemComponent -IncludeEngine

.EXAMPLE
    powershell -NoProfile -File scripts/find-uclass.ps1 -Name DOREPLIFETIME_CONDITION -IncludeEngine
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Name,
    [switch]$IncludeEngine,
    [int]$MaxHits = 20
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Reuse detect-engine.ps1 to find project + engine paths
$detect = Join-Path $scriptDir 'detect-engine.ps1'
if (-not (Test-Path $detect)) {
    Write-Error "Sibling detect-engine.ps1 not found at $detect"
    exit 1
}
$info = & $detect -Format json | ConvertFrom-Json

function Search-Dir {
    param([string]$Dir, [string]$Pattern, [int]$Cap, [string]$Label)
    if (-not (Test-Path $Dir)) {
        Write-Output "[$Label] path not found: $Dir"
        return
    }
    Write-Output ""
    Write-Output "=== $Label : $Dir ==="
    $count = 0
    Get-ChildItem -LiteralPath $Dir -Recurse -Include *.h,*.cpp,*.hpp -ErrorAction SilentlyContinue | ForEach-Object {
        if ($count -ge $Cap) { return }
        $matches = Select-String -LiteralPath $_.FullName -Pattern $Pattern -SimpleMatch:$false -CaseSensitive
        foreach ($m in $matches) {
            if ($count -ge $Cap) { break }
            Write-Output ("{0}:{1}: {2}" -f $_.FullName, $m.LineNumber, $m.Line.Trim())
            $count++
        }
    }
    Write-Output "($count match(es), capped at $Cap)"
}

$wordPattern = "\b$([regex]::Escape($Name))\b"

# 1. Project source
$projSrc = Join-Path $info.ProjectRoot 'Source'
Search-Dir -Dir $projSrc -Pattern $wordPattern -Cap $MaxHits -Label "Project Source"

# 1b. Project plugins
$plugSrc = Join-Path $info.ProjectRoot 'Plugins'
if (Test-Path $plugSrc) {
    Search-Dir -Dir $plugSrc -Pattern $wordPattern -Cap $MaxHits -Label "Project Plugins"
}

# 2. Engine source
if ($IncludeEngine) {
    if ($info.EnginePath -and $info.EnginePath -ne '?' -and (Test-Path $info.EnginePath)) {
        $engRuntime = Join-Path $info.EnginePath 'Engine\Source\Runtime'
        Search-Dir -Dir $engRuntime -Pattern $wordPattern -Cap $MaxHits -Label "Engine Runtime"

        $engPlugins = Join-Path $info.EnginePath 'Engine\Plugins'
        if (Test-Path $engPlugins) {
            Search-Dir -Dir $engPlugins -Pattern $wordPattern -Cap $MaxHits -Label "Engine Plugins"
        }
    } else {
        Write-Output ""
        Write-Output "[Engine source not resolved — pass -EnginePath or install the launcher build]"
    }
}

Write-Output ""
Write-Output "If zero hits everywhere, the symbol almost certainly does not exist in this version."
Write-Output "Next step: WebFetch https://dev.epicgames.com/documentation/en-us/unreal-engine and search for '$Name'."
