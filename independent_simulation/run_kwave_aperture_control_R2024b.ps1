param([switch]$TestsOnly)
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'results/kwave_aperture_control_2026-10-23'
$runTmp=Join-Path $PSScriptRoot 'tmp'
New-Item -ItemType Directory -Force -Path $out,$runTmp | Out-Null
$priorTemp=$env:TEMP; $priorTmp=$env:TMP
try {
    $env:TEMP=$runTmp; $env:TMP=$env:TEMP
    $expression='verify_aperture_control;'
    if (-not $TestsOnly) { $expression+=' run_kwave_aperture_control;' }
    $log=Join-Path $out ('run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
    & 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe' -wait -nosplash -sd $PSScriptRoot -batch $expression -logfile $log
    if ($LASTEXITCODE -ne 0) { throw "Aperture control failed: $LASTEXITCODE" }
} finally { $env:TEMP=$priorTemp; $env:TMP=$priorTmp }
