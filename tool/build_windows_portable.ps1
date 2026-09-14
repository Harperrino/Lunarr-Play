param(
    [string]$OutputDirectory = "release",
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$releaseSource = Join-Path $projectRoot "build\windows\x64\runner\Release"
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $projectRoot $OutputDirectory
}
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("lunarr-portable-" + [guid]::NewGuid())
$stagingDirectory = Join-Path $temporaryRoot "app"

function Copy-RequiredFile {
    param([string]$Source, [string]$Destination)

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required file is missing: $Source"
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

try {
    if (-not $SkipFlutterBuild) {
        Push-Location $projectRoot
        try {
            & flutter build windows --release --no-pub
            if ($LASTEXITCODE -ne 0) {
                throw "Flutter Windows build failed with exit code $LASTEXITCODE."
            }
        } finally {
            Pop-Location
        }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $releaseSource "lunarr_one.exe") -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $releaseSource "data") -PathType Container)) {
        throw "The Flutter Windows release bundle is incomplete."
    }

    $versionLine = @(Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(.+)$')
    if ($versionLine.Count -ne 1) {
        throw "pubspec.yaml must contain exactly one version field."
    }
    $packageVersion = $versionLine.Matches[0].Groups[1].Value.Trim().Split('+')[0]
    if ($packageVersion -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
        throw "Unsupported package version: $packageVersion"
    }

    New-Item -ItemType Directory -Path $stagingDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
    Copy-Item -Path (Join-Path $releaseSource '*') -Destination $stagingDirectory -Recurse -Force

    Copy-RequiredFile (Join-Path $projectRoot "LICENSE") (Join-Path $stagingDirectory "LICENSE.txt")
    Copy-RequiredFile (Join-Path $projectRoot "THIRD_PARTY_NOTICES.md") (Join-Path $stagingDirectory "THIRD_PARTY_NOTICES.md")
    Copy-Item -LiteralPath (Join-Path $projectRoot "third_party_licenses") -Destination $stagingDirectory -Recurse -Force

    @(
        "data\flutter_assets\kernel_blob.bin",
        "data\flutter_assets\isolate_snapshot_data",
        "data\flutter_assets\vm_snapshot_data"
    ) | ForEach-Object {
        $candidate = Join-Path $stagingDirectory $_
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Remove-Item -LiteralPath $candidate -Force
        }
    }

    $visualStudioRoots = @(
        (Join-Path ${env:ProgramFiles} "Microsoft Visual Studio"),
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }
    $runtimeDirectory = $visualStudioRoots |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Recurse -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue } |
        Where-Object {
            $_.FullName -match '[\\/]x64[\\/]' -and
            $_.FullName -notmatch '[\\/]OneCore[\\/]' -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "msvcp140.dll")) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "vcruntime140.dll")) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "vcruntime140_1.dll"))
        } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $runtimeDirectory) {
        throw "A complete x64 Visual C++ runtime directory was not found."
    }
    @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll") | ForEach-Object {
        Copy-Item -LiteralPath (Join-Path $runtimeDirectory.FullName $_) -Destination $stagingDirectory -Force
    }

    Push-Location $projectRoot
    try {
        & dart run tool/release_privacy_scan.dart $stagingDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Release privacy scan failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }

    $artifactName = "Lunarr-Player-$packageVersion-windows-x64-portable.zip"
    $artifactPath = Join-Path $resolvedOutput $artifactName
    if (Test-Path -LiteralPath $artifactPath) {
        Remove-Item -LiteralPath $artifactPath -Force
    }
    Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $artifactPath -CompressionLevel Optimal

    $hash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath "$artifactPath.sha256" -Value "$hash  $artifactName" -Encoding ascii
    $sizeMiB = [math]::Round((Get-Item -LiteralPath $artifactPath).Length / 1MB, 2)
    Write-Host "Windows portable archive created: $artifactPath ($sizeMiB MiB)"
    Write-Host "SHA-256: $hash"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
