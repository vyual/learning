$ErrorActionPreference = "Stop"

$sourcePath = $PSScriptRoot
$manifestPath = Join-Path $sourcePath "info.json"
$modsPath = Join-Path $env:APPDATA "Factorio\mods"
$scriptPath = $PSCommandPath
$excludedNames = @(
    ".git",
    ".vscode",
    ".gitignore",
    ".luarc.json",
    "README.md",
    "LICENSE",
    "LICENSE.md",
    "CHANGELOG.md",
    "deploy-mod-on-save.ps1",
    "bump-version.ps1",
    "check-install.ps1"
)

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Manifest file not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($manifest.name -notmatch '^[A-Za-z0-9_-]+$') {
    throw "Invalid or missing mod name in info.json: '$($manifest.name)'"
}

if ($manifest.version -notmatch '^\d+(?:\.\d+){1,3}$') {
    throw "Invalid or missing mod version in info.json: '$($manifest.version)'"
}

$destinationPath = Join-Path $modsPath "$($manifest.name)_$($manifest.version)"
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

Get-ChildItem -LiteralPath $sourcePath -Force |
    Where-Object {
        $_.Name -notin $excludedNames -and
        $_.FullName -ne $scriptPath -and
        $_.Name -ne "update-mod.ps1"
    } |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Recurse -Force
    }

Write-Host "Mod copied to: $destinationPath"
