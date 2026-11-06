param([switch]$TestsOnly)
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'results/kwave_singlepoint_validation_2026-10-22'
$runTmp=Join-Path $PSScriptRoot 'tmp'
New-Item -ItemType Directory -Force -Path $out,$runTmp | Out-Null
$priorTemp=$env:TEMP; $priorTmp=$env:TMP
try {
    $env:TEMP=$runTmp; $env:TMP=$runTmp
    $expression='verify_kwave_singlepoint_validation;'
    if (-not $TestsOnly) { $expression+=' run_kwave_singlepoint_validation;' }
    $logPrefix=if ($TestsOnly) { 'tests' } else { 'solver' }
    $logPath=Join-Path $out ($logPrefix+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
    Write-Host "MATLAB log: $logPath"
    & 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe' -wait -nosplash -sd $PSScriptRoot -batch $expression -logfile $logPath
    if ($LASTEXITCODE -ne 0) { throw "Single-point validation failed: $LASTEXITCODE" }
} finally {
    $env:TEMP=$priorTemp; $env:TMP=$priorTmp
}
