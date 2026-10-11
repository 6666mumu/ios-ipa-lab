[CmdletBinding()]
param([string]$SdkDirectory = (Join-Path $env:USERPROFILE 'develop\flutter'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

foreach ($tool in @(@{ Name = 'git'; Id = 'Git.Git' }, @{ Name = 'gh'; Id = 'GitHub.cli' })) {
    if (-not (Get-Command $tool.Name -ErrorAction SilentlyContinue)) {
        & winget install --id $tool.Id --exact --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw ('Installation failed: ' + $tool.Name) }
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }
}
$version = (Get-Content -LiteralPath (Join-Path $projectRoot '.flutter-version') -Raw).Trim()
$revision = (Get-Content -LiteralPath (Join-Path $projectRoot '.flutter-revision') -Raw).Trim()
if (-not (Test-Path -LiteralPath $SdkDirectory)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $SdkDirectory) -Force | Out-Null
    & git clone --depth 1 --branch $version https://github.com/flutter/flutter.git $SdkDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Flutter download failed.' }
}
$actual = & git -C $SdkDirectory rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $actual -ne $revision) { throw 'Existing SDK is not the pinned revision. Use -SdkDirectory to select a separate installation.' }
$flutterBin = Join-Path $SdkDirectory 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $flutterBin) { [Environment]::SetEnvironmentVariable('Path', $flutterBin + ';' + $userPath, 'User') }
$env:Path = $flutterBin + ';' + $env:Path
$env:FLUTTER_ROOT = $SdkDirectory
& (Join-Path $flutterBin 'flutter.bat') config --no-analytics
if ($LASTEXITCODE -ne 0) { throw 'Flutter initialization failed.' }
& (Join-Path $flutterBin 'dart.bat') --disable-analytics

. (Join-Path $PSScriptRoot 'Use-Toolchain.ps1')
try { $toolchain = Get-LabToolchain } catch {
    if ($_.Exception.Message -notmatch '^Python') { throw }
    & winget install --id Python.Python.3.13 --exact --scope user --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'Python installation failed.' }
    $toolchain = Get-LabToolchain
}
& $toolchain.Flutter --version
& $toolchain.Python --version
& gh auth status
Write-Host 'Setup complete. Missing workflow scope can be added with: gh auth refresh -h github.com -s workflow'
Write-Host ('ASCII workspace: ' + $toolchain.WorkingRoot)
