Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LabToolchain {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $sdkRoot = if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT } else { Join-Path $env:USERPROFILE 'develop\flutter' }
    $flutterExe = Join-Path $sdkRoot 'bin\flutter.bat'
    if (-not (Test-Path -LiteralPath $flutterExe)) { throw 'Flutter is missing. Run scripts/Setup-Windows.ps1 first.' }
    $env:Path = (Join-Path $sdkRoot 'bin') + ';' + $env:Path
    $expected = (Get-Content -LiteralPath (Join-Path $projectRoot '.flutter-revision') -Raw).Trim()
    $actual = & git -C $sdkRoot rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) { throw 'Flutter revision differs from .flutter-revision. Select the pinned SDK using FLUTTER_ROOT.' }
    $pythonCandidates = @(
        $env:IPA_LAB_PYTHON,
        (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe')
    )
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand -and $pythonCommand.Source -notmatch 'WindowsApps') { $pythonCandidates += $pythonCommand.Source }
    $pythonExe = $pythonCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $pythonExe) { throw 'Python 3.9+ is needed for IPA verification. Set IPA_LAB_PYTHON to an existing python.exe or run Setup-Windows.ps1.' }

    # Dart LSP can miscount UTF-8 bytes in a non-ASCII Windows workspace path.
    # A junction supplies an ASCII working directory without moving any source.
    $workingRoot = $projectRoot
    if ($projectRoot -match '[^\x00-\x7F]') {
        $bytes = [Text.Encoding]::UTF8.GetBytes($projectRoot.ToLowerInvariant())
        $digest = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-', '').Substring(0, 10).ToLowerInvariant()
        $aliasParent = Join-Path $env:USERPROFILE 'develop\workspaces'
        $workingRoot = Join-Path $aliasParent ('ipa-lab-' + $digest)
        New-Item -ItemType Directory -Path $aliasParent -Force | Out-Null
        if (-not (Test-Path -LiteralPath $workingRoot)) { New-Item -ItemType Junction -Path $workingRoot -Target $projectRoot | Out-Null }
        $link = Get-Item -LiteralPath $workingRoot
        if ($link.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath([string]$link.Target) -ne [IO.Path]::GetFullPath($projectRoot)) {
            throw 'The ASCII workspace alias points somewhere unexpected.'
        }
    }
    [pscustomobject]@{ Root = $projectRoot; WorkingRoot = $workingRoot; Flutter = $flutterExe; Python = $pythonExe }
}
