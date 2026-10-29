# Только чтение: исходники и установленная копия не изменяются.
param([string]$ModsPath = (Join-Path $env:APPDATA "Factorio\mods"))
$ErrorActionPreference = "Stop"
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot "info.json") -Raw | ConvertFrom-Json
$installed = Join-Path $ModsPath "$($manifest.name)_$($manifest.version)"
if (-not (Test-Path -LiteralPath $installed -PathType Container)) {
    throw "Installed folder not found: $installed. Check Factorio's loaded version in factorio-current.log."
}
$files = @("info.json", "control.lua", "data.lua")
foreach ($folder in @("scripts", "prototypes", "locale", "graphics")) {
    $prefix = $PSScriptRoot.TrimEnd('\') + '\'
    $files += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $folder) -File -Recurse |
        ForEach-Object { $_.FullName.Substring($prefix.Length) }
}
$mismatches = @()
foreach ($relative in $files) {
    $target = Join-Path $installed $relative
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $mismatches += "MISSING: $relative"
    } elseif ((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $relative)).Hash -ne
              (Get-FileHash -LiteralPath $target).Hash) {
        $mismatches += "DIFFERENT: $relative"
    }
}
Write-Output "Source: $PSScriptRoot"
Write-Output "Installed: $installed"
if ($mismatches.Count -gt 0) {
    $mismatches | ForEach-Object { Write-Output $_ }
    throw "Installed mod differs from source. Update the installed copy using update-mod.ps1, then fully restart Factorio. Reloading a save is not enough."
}
Write-Output "MATCH: all $($files.Count) runtime files have identical SHA256 hashes. Fully restart Factorio if it was open during the update."
