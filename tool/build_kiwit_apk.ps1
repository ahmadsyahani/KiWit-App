$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Build APK gagal.' }
    $outputDir = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
    Copy-Item -LiteralPath (Join-Path $outputDir 'app-release.apk') -Destination (Join-Path $outputDir 'KiWit.apk')
    Write-Output ('APK KiWit: ' + (Join-Path $outputDir 'KiWit.apk'))
} finally {
    Pop-Location
}
