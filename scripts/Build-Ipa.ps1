[CmdletBinding()]
param([switch]$Push, [switch]$PublishRelease, [string]$Branch = 'main')
. (Join-Path $PSScriptRoot 'Use-Toolchain.ps1')
$toolchain = Get-LabToolchain
Push-Location -LiteralPath $toolchain.WorkingRoot
try {
    & (Join-Path $PSScriptRoot 'Run-Checks.ps1')
    if ((& git status --porcelain)) { throw 'Commit the intended source changes first. This script never stages personal files automatically.' }
    $currentBranch = & git branch --show-current
    if ($currentBranch -ne $Branch) { throw 'Select the requested branch before building.' }
    $commit = (& git rev-parse HEAD).Trim()
    $repo = (& gh repo view --json nameWithOwner --jq .nameWithOwner).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'GitHub repository could not be resolved.' }
    if ($Push) {
        & git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin $Branch
        if ($LASTEXITCODE -ne 0) { throw 'Git push failed.' }
    }
    $remoteCommit = (& gh api "repos/$repo/commits/$Branch" --jq .sha).Trim()
    if ($remoteCommit -ne $commit) { throw 'Remote branch differs from local HEAD. Run with -Push after reviewing your commit.' }
    $started = [DateTimeOffset]::UtcNow.AddSeconds(-5)
    & gh workflow run ios-unsigned.yml --repo $repo --ref $Branch
    if ($LASTEXITCODE -ne 0) { throw 'Workflow dispatch failed.' }
    $run = $null
    for ($attempt = 0; $attempt -lt 15; $attempt++) {
        $runs = & gh run list --repo $repo --workflow ios-unsigned.yml --branch $Branch --event workflow_dispatch --limit 10 --json databaseId,number,headSha,createdAt,url
        if ($LASTEXITCODE -ne 0) { throw 'Workflow listing failed.' }
        $run = $runs | ConvertFrom-Json | Where-Object { $_.headSha -eq $commit -and [DateTimeOffset]::Parse($_.createdAt) -ge $started } | Select-Object -First 1
        if ($run) { break }
        Start-Sleep -Seconds 3
    }
    if (-not $run) { throw 'Dispatch accepted, but no run was located. Check the repository Actions page before dispatching again.' }
    Write-Host ('Build: ' + $run.url)
    & gh run watch $run.databaseId --repo $repo --exit-status --interval 10
    if ($LASTEXITCODE -ne 0) { throw ('Cloud build failed. Inspect: ' + $run.url) }
    $outputDir = Join-Path $toolchain.Root ('artifacts\' + $run.databaseId)
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    & gh run download $run.databaseId --repo $repo --name ('unsigned-ipa-' + $run.number) --dir $outputDir
    if ($LASTEXITCODE -ne 0) { throw 'Artifact download failed.' }
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
        & gh release create $tag $ipa (Join-Path $outputDir 'IPA-Lab-unsigned.json') (Join-Path $outputDir 'SHA256SUMS.txt') --repo $repo --target $commit --title ('Unsigned IPA test build ' + $run.number) --notes-file $notes
        if ($LASTEXITCODE -ne 0) { throw 'Release publication failed; the verified IPA remains in artifacts.' }
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
