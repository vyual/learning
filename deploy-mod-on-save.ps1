$ErrorActionPreference = "Stop"

$sourcePath = $PSScriptRoot
$manifestPath = Join-Path $sourcePath "info.json"
$modsPath = Join-Path $env:APPDATA "Factorio\mods"
$archivePath = Join-Path (Split-Path $sourcePath -Parent) "temp"
$scriptNames = @(
  ".git",
  ".gitignore",
  "README.md",
  "LICENSE",
  "LICENSE.md",
  "CHANGELOG.md",
  "deploy-mod-on-save.ps1",
  "update-mod.ps1",
  "bump-version.ps1",
  ".luarc.json"
)

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Manifest file not found: $manifestPath"
}

$json = [System.IO.File]::ReadAllText(
    $manifestPath,
    [System.Text.Encoding]::UTF8
)
$manifest = $json | ConvertFrom-Json

if ($manifest.name -notmatch '^[A-Za-z0-9_-]+$') {
    throw "Invalid or missing mod name in info.json: '$($manifest.name)'"
}

$versionPattern = '("version"\s*:\s*")(\d+)\.(\d+)\.(\d+)(")'
$versionMatches = [regex]::Matches($json, $versionPattern)
if ($versionMatches.Count -ne 1) {
    throw "Expected exactly one three-part version in info.json."
}

$versionMatch = $versionMatches[0]
$oldVersion = "$($versionMatch.Groups[2].Value).$($versionMatch.Groups[3].Value).$($versionMatch.Groups[4].Value)"
if ($manifest.version -ne $oldVersion) {
    throw "Could not read the version consistently from info.json."
}

$oldInstallPath = Join-Path $modsPath "$($manifest.name)_$oldVersion"
$oldContentPath = if (Test-Path -LiteralPath $oldInstallPath -PathType Container) {
    $oldInstallPath
} else {
    $sourcePath
}

New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
$archiveFile = Join-Path $archivePath "$($manifest.name)_$oldVersion.zip"
$archiveItems = @(Get-ChildItem -LiteralPath $oldContentPath -Force |
    Where-Object {
        $_.Name -ne ".vscode" -and
        $_.Name -notin $scriptNames
    })

if ($archiveItems.Count -eq 0) {
    throw "No mod files found to archive in: $oldContentPath"
}

Compress-Archive -LiteralPath $archiveItems.FullName -DestinationPath $archiveFile -Force

$major = [long]$versionMatch.Groups[2].Value
$minor = [long]$versionMatch.Groups[3].Value
$patch = [long]$versionMatch.Groups[4].Value + 1
$newVersion = "$major.$minor.$patch"
$newJson = $json.Substring(0, $versionMatch.Index) +
    $versionMatch.Groups[1].Value +
    $newVersion +
    $versionMatch.Groups[5].Value +
    $json.Substring($versionMatch.Index + $versionMatch.Length)

[System.IO.File]::WriteAllText(
    $manifestPath,
    $newJson,
    [System.Text.UTF8Encoding]::new($false)
)

$destinationPath = Join-Path $modsPath "$($manifest.name)_$newVersion"
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
Get-ChildItem -LiteralPath $sourcePath -Force |
    Where-Object {
        $_.Name -ne ".vscode" -and
        $_.Name -notin $scriptNames
    } |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Recurse -Force
    }

if ((Test-Path -LiteralPath $oldInstallPath -PathType Container) -and
    $oldInstallPath -ne $destinationPath) {
    Remove-Item -LiteralPath $oldInstallPath -Recurse -Force
}

$archivePattern = '^' + [regex]::Escape($manifest.name) + '_\d+\.\d+\.\d+\.zip$'
$archiveVersionPattern = '_(\d+)\.(\d+)\.(\d+)\.zip$'
$archives = @(Get-ChildItem -LiteralPath $archivePath -File |
    Where-Object { $_.Name -match $archivePattern } |
    Sort-Object `
        @{ Expression = { [long]([regex]::Match($_.Name, $archiveVersionPattern).Groups[1].Value) } }, `
        @{ Expression = { [long]([regex]::Match($_.Name, $archiveVersionPattern).Groups[2].Value) } }, `
        @{ Expression = { [long]([regex]::Match($_.Name, $archiveVersionPattern).Groups[3].Value) } })

if ($archives.Count -gt 5) {
    $archives | Select-Object -First ($archives.Count - 5) | Remove-Item -Force
}

Write-Output "Version updated: $oldVersion -> $newVersion"
Write-Output "Archived previous version: $archiveFile"
Write-Output "Installed mod: $destinationPath"
