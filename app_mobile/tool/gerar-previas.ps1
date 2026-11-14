param([string]$FlutterSdk)

$ErrorActionPreference = 'Stop'
if (-not $FlutterSdk) {
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $FlutterSdk = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
}
$FlutterSdk = (Resolve-Path -LiteralPath $FlutterSdk).Path
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    if (-not (Test-Path 'build/unit_test_assets/FontManifest.json')) {
        throw 'Execute flutter pub get e flutter test antes de gerar as previas.'
    }
    $runtimePath = Join-Path $projectRoot '.dart_tool/visual_preview'
    New-Item -ItemType Directory -Force $runtimePath | Out-Null
    $enginePath = Join-Path $FlutterSdk 'bin/cache/artifacts/engine/windows-x64'
    $dartRuntime = Join-Path $FlutterSdk 'bin/cache/dart-sdk/bin/dartaotruntime.exe'
    $compiler = Join-Path $enginePath 'frontend_server_aot.dart.snapshot'
    $sdkRoot = Join-Path $FlutterSdk 'bin/cache/artifacts/engine/common/flutter_patched_sdk'
    $kernelPath = Join-Path $runtimePath 'preview.dill'
    $compileLog = Join-Path $runtimePath 'compile.log'
    & $dartRuntime $compiler --sdk-root $sdkRoot --target=flutter --packages .dart_tool/package_config.json --output-dill $kernelPath test/visual_preview.dart > $compileLog 2>&1
    $lastLine = Get-Content -LiteralPath $compileLog -Tail 1
    if ($LASTEXITCODE -ne 0 -or $lastLine -notmatch ' 0$') {
        Get-Content -LiteralPath $compileLog | Select-String 'Error:|error:' -Context 1,2
        throw "Falha na compilacao; consulte $compileLog"
    }
    $renderer = Join-Path $enginePath 'flutter_tester.exe'
    & $renderer --disable-vm-service --enable-software-rendering --run-forever --flutter-assets-dir=build/unit_test_assets $kernelPath
    if ($LASTEXITCODE -ne 0) { throw 'A renderizacao encontrou erros.' }
    Write-Output 'Previas salvas em evidencias/sprint3/revisao-ui. Dados demonstrativos; nao usar como prova de integracao.'
} finally {
    Pop-Location
}
