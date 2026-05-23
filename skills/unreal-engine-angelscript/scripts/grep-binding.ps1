#requires -Version 5.1
<#
.SYNOPSIS
    Search for an AngelScript symbol or its C++ binding origin across the project.

.DESCRIPTION
    Runs two greps:
      1. Project Script/ for whole-word matches in *.as files.
      2. Project Source/ for the corresponding C++ binding (UFUNCTION / UPROPERTY / UCLASS).
      3. Optionally Plugins/ for both layers.

    Prints up to -MaxHits matches per scope with file path + line + context.
    Also surfaces any "NotInAngelscript" / "NoAutoAngelscriptBind" meta near the match.

.PARAMETER Name
    The symbol name (class, function, property) to look for.

.PARAMETER IncludePlugins
    Also search Plugins/ subdirectories.

.PARAMETER MaxHits
    Cap results per scope. Default 25.

.EXAMPLE
    powershell -NoProfile -File scripts/grep-binding.ps1 -Name UBoardStateComponent
.EXAMPLE
    powershell -NoProfile -File scripts/grep-binding.ps1 -Name PlaceObject -IncludePlugins
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Name,
    [switch]$IncludePlugins,
    [int]$MaxHits = 25
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

$uproj = Find-UProject -From (Get-Location).Path
if (-not $uproj) { Write-Error "No *.uproject found from current directory."; exit 1 }
$projRoot = $uproj.Directory.FullName

$wordPattern = "\b$([regex]::Escape($Name))\b"

function Search-Dir {
    param([string]$Dir, [string]$Pattern, [string[]]$Include, [int]$Cap, [string]$Label)
    if (-not (Test-Path $Dir)) {
        Write-Output "[$Label] not present: $Dir"
        return 0
    }
    Write-Output ""
    Write-Output "=== $Label : $Dir ==="
    $count = 0
    Get-ChildItem -LiteralPath $Dir -Recurse -Include $Include -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($count -ge $Cap) { return }
        $matches = Select-String -LiteralPath $_.FullName -Pattern $Pattern -CaseSensitive
        foreach ($m in $matches) {
            if ($count -ge $Cap) { break }
            $contextNote = ''
            if ($m.Line -match 'NotInAngelscript|NoAutoAngelscriptBind') {
                $contextNote = '  *** HIDDEN FROM AS ***'
            }
            Write-Output ("{0}:{1}: {2}{3}" -f $_.FullName, $m.LineNumber, $m.Line.Trim(), $contextNote)
            $count++
        }
    }
    Write-Output "($count match(es), capped at $Cap)"
    return $count
}

$scriptDir = Join-Path $projRoot 'Script'
$sourceDir = Join-Path $projRoot 'Source'
$pluginsDir = Join-Path $projRoot 'Plugins'

$asHits  = Search-Dir -Dir $scriptDir -Pattern $wordPattern -Include @('*.as')          -Cap $MaxHits -Label 'AngelScript (.as)'
$cppHits = Search-Dir -Dir $sourceDir -Pattern $wordPattern -Include @('*.h','*.cpp')   -Cap $MaxHits -Label 'C++ Source (binding origin)'

if ($IncludePlugins -and (Test-Path $pluginsDir)) {
    Search-Dir -Dir $pluginsDir -Pattern $wordPattern -Include @('*.as')        -Cap $MaxHits -Label 'Plugin .as files'  | Out-Null
    Search-Dir -Dir $pluginsDir -Pattern $wordPattern -Include @('*.h','*.cpp') -Cap $MaxHits -Label 'Plugin C++ Source' | Out-Null
}

Write-Output ""
if (($asHits + $cppHits) -eq 0) {
    Write-Output "No matches. Next steps:"
    Write-Output "  1. WebFetch https://angelscript.hazelight.se/api and search for '$Name'."
    Write-Output "  2. WebFetch the Hazelight engine fork:"
    Write-Output "     https://github.com/Hazelight/UnrealEngine-Angelscript"
    Write-Output "  3. If still unresolved, ask the user to confirm the symbol."
} else {
    Write-Output "Look for *** HIDDEN FROM AS *** annotations above — those C++ members exist but are not bound to AS."
}
