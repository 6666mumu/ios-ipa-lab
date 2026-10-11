[CmdletBinding()]
param([switch]$BuildWeb)
. (Join-Path $PSScriptRoot 'Use-Toolchain.ps1')
$toolchain = Get-LabToolchain
Push-Location -LiteralPath $toolchain.WorkingRoot
try {
    & $toolchain.Python ci/check_repository.py
    if ($LASTEXITCODE -ne 0) { throw 'Repository check failed.' }
    & $toolchain.Flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Locked dependency check failed.' }
    & dart format --output=none --set-exit-if-changed lib test
    if ($LASTEXITCODE -ne 0) { throw 'Dart formatting check failed.' }
    & $toolchain.Flutter analyze --fatal-infos
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    & $toolchain.Flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    if ($BuildWeb) {
        & $toolchain.Flutter build web --release
        if ($LASTEXITCODE -ne 0) { throw 'Web release build failed.' }
    }
} finally { Pop-Location }
