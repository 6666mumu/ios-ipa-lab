[CmdletBinding()]
param(
    [switch]$Push,
    [switch]$PublishRelease,
    [string]$Branch = 'main',
    [ValidateRange(0, [long]::MaxValue)][long]$RunId = 0
)
. (Join-Path $PSScriptRoot 'Use-Toolchain.ps1')
$toolchain = Get-LabToolchain
Push-Location -LiteralPath $toolchain.WorkingRoot
try {
    $repo = (& gh repo view --json nameWithOwner --jq .nameWithOwner).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'GitHub repository could not be resolved.' }
    if ($RunId -gt 0) {
        if ($Push) { throw '-RunId resumes an existing build and cannot be combined with -Push.' }
        $runData = & gh api "repos/$repo/actions/runs/$RunId"
        if ($LASTEXITCODE -ne 0) { throw 'The requested workflow run could not be read.' }
        $details = $runData | ConvertFrom-Json
        if ($details.path -ne '.github/workflows/ios-unsigned.yml' -or $details.event -ne 'workflow_dispatch') {
            throw 'The requested run does not belong to the unsigned IPA workflow.'
        }
        $run = [pscustomobject]@{
            databaseId = $details.id; number = $details.run_number
            headSha = $details.head_sha; url = $details.html_url
        }
        # A resumed run always refers to its actual source, even after local documentation changes.
        $commit = $run.headSha
    } else {
        & (Join-Path $PSScriptRoot 'Run-Checks.ps1')
        if ((& git status --porcelain)) { throw 'Commit the intended source changes first. This script never stages personal files automatically.' }
        $currentBranch = & git branch --show-current
        if ($currentBranch -ne $Branch) { throw 'Select the requested branch before building.' }
        $commit = (& git rev-parse HEAD).Trim()
        if ($Push) {
            & git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin $Branch
            if ($LASTEXITCODE -ne 0) { throw 'Git push failed.' }
        }
        $remoteCommit = (& gh api "repos/$repo/commits/$Branch" --jq .sha).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Remote branch could not be read.' }
        if ($remoteCommit -ne $commit) { throw 'Remote branch differs from local HEAD. Run with -Push after reviewing your commit.' }
        $previousRuns = & gh run list --repo $repo --workflow ios-unsigned.yml --branch $Branch --event workflow_dispatch --limit 100 --json databaseId
        if ($LASTEXITCODE -ne 0) { throw 'Existing workflow runs could not be read.' }
        $previousIds = @($previousRuns | ConvertFrom-Json | ForEach-Object { $_.databaseId })
        & gh workflow run ios-unsigned.yml --repo $repo --ref $Branch
        if ($LASTEXITCODE -ne 0) { throw 'Workflow dispatch failed.' }
        $run = $null
        for ($attempt = 0; $attempt -lt 15; $attempt++) {
            $runs = & gh run list --repo $repo --workflow ios-unsigned.yml --branch $Branch --event workflow_dispatch --limit 10 --json databaseId,number,headSha,url
            if ($LASTEXITCODE -ne 0) { throw 'Workflow listing failed. Resume the accepted run with -RunId after checking Actions.' }
            # Compare immutable IDs instead of reparsing JSON dates in the Windows time zone.
            $candidates = @($runs | ConvertFrom-Json | Where-Object { $_.headSha -eq $commit -and $_.databaseId -notin $previousIds })
            if ($candidates.Count -gt 1) { throw 'Multiple new runs found. Choose the intended run on Actions and resume with -RunId.' }
            if ($candidates.Count -eq 1) { $run = $candidates[0]; break }
            Start-Sleep -Seconds 3
        }
        if (-not $run) { throw 'Dispatch accepted, but no run was located. Check Actions and use -RunId; do not dispatch again.' }
    }
    Write-Host ('Build: ' + $run.url)
    & gh run watch $run.databaseId --repo $repo --exit-status --interval 10
    if ($LASTEXITCODE -ne 0) { throw ('Cloud build failed. Inspect: ' + $run.url) }
    $outputDir = Join-Path $toolchain.Root ('artifacts\' + $run.databaseId)
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    # gh run download refuses existing files. Stage a fresh copy so an interrupted run can resume.
    $downloadDir = Join-Path $outputDir ('.download-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $downloadDir | Out-Null
    try {
        & gh run download $run.databaseId --repo $repo --name ('unsigned-ipa-' + $run.number) --dir $downloadDir
        if ($LASTEXITCODE -ne 0) { throw 'Artifact download failed.' }
        Get-ChildItem -LiteralPath $downloadDir | Copy-Item -Destination $outputDir -Recurse -Force
    } finally {
        $resolvedDownload = (Resolve-Path -LiteralPath $downloadDir).ProviderPath
        $resolvedOutput = (Resolve-Path -LiteralPath $outputDir).ProviderPath
        if ([IO.Path]::GetDirectoryName($resolvedDownload) -ne $resolvedOutput -or
            (Get-Item -LiteralPath $resolvedDownload).LinkType) {
            throw 'Refusing to clean a download directory outside the selected artifact directory.'
        }
        Remove-Item -LiteralPath $resolvedDownload -Recurse -Force
    }
    $artifactCommit = (Get-Content -LiteralPath (Join-Path $outputDir 'source-commit.txt') -Raw).Trim()
    if ($artifactCommit -ne $commit) { throw 'Artifact source commit differs from the selected workflow run.' }
    $ipa = Join-Path $outputDir 'IPA-Lab-unsigned.ipa'
    $localReport = Join-Path $outputDir 'windows-verification.json'
    & $toolchain.Python ci/verify_ipa.py $ipa --report $localReport
    if ($LASTEXITCODE -ne 0) { throw 'Downloaded IPA verification failed.' }
    $expectedHash = ((Get-Content -LiteralPath (Join-Path $outputDir 'SHA256SUMS.txt') -Raw) -split '\s+')[0]
    if ((Get-FileHash -LiteralPath $ipa -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) { throw 'Downloaded IPA checksum differs from the cloud checksum.' }
    $releaseUrl = $null
    $downloadUrl = $null
    if ($PublishRelease) {
        $tag = 'ipa-build-' + $run.databaseId
        $notes = Join-Path $outputDir 'release-notes.md'
        @(
            'Unsigned iOS device IPA, built with Flutter on a standard GitHub macOS runner.',
            '',
            ('Source: ' + $commit),
            ('Build log: ' + $run.url),
            ('SHA-256: ' + $expectedHash),
            '',
            'Import the .ipa into your local signing tool. Match its Bundle ID and entitlements to your own provisioning profile.',
            'No certificate, private key, password or provisioning profile was uploaded. Device installation and launch are not yet verified.'
        ) | Set-Content -LiteralPath $notes -Encoding utf8
        $existingRelease = & gh release view $tag --repo $repo --json url 2>$null
        if ($LASTEXITCODE -eq 0) {
            $releaseCommit = (& gh api "repos/$repo/commits/$tag" --jq .sha).Trim()
            if ($LASTEXITCODE -ne 0 -or $releaseCommit -ne $commit) { throw 'Existing release tag does not match the selected build.' }
            $releaseCheckDir = Join-Path $outputDir 'release-verification'
            New-Item -ItemType Directory -Path $releaseCheckDir -Force | Out-Null
            & gh release download $tag --repo $repo --pattern 'IPA-Lab-unsigned.ipa' --dir $releaseCheckDir --clobber
            if ($LASTEXITCODE -ne 0) { throw 'Existing release IPA could not be verified.' }
            $releaseHash = (Get-FileHash -LiteralPath (Join-Path $releaseCheckDir 'IPA-Lab-unsigned.ipa') -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($releaseHash -ne $expectedHash) { throw 'Existing release IPA differs from the selected build; no assets were replaced.' }
            Write-Host ('Verified existing release: ' + ($existingRelease | ConvertFrom-Json).url)
        } else {
            & gh release create $tag $ipa (Join-Path $outputDir 'IPA-Lab-unsigned.json') (Join-Path $outputDir 'SHA256SUMS.txt') --repo $repo --target $commit --title ('Unsigned IPA test build ' + $run.number) --notes-file $notes
            if ($LASTEXITCODE -ne 0) { throw 'Release publication failed; the verified IPA remains in artifacts.' }
        }
        $releaseUrl = "https://github.com/$repo/releases/tag/$tag"
        $downloadUrl = "https://github.com/$repo/releases/download/$tag/IPA-Lab-unsigned.ipa"
    }
    [ordered]@{
        repository = $repo; commit = $commit; run_id = $run.databaseId; run_number = $run.number
        run_url = $run.url; cloud_build = 'success'; ipa = $ipa; sha256 = $expectedHash
        release_url = $releaseUrl; download_url = $downloadUrl; installation_verified = $false
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDir 'build-result.json') -Encoding utf8
    Write-Host ('IPA: ' + $ipa)
    if ($downloadUrl) { Write-Host ('Download: ' + $downloadUrl) }
} finally { Pop-Location }
