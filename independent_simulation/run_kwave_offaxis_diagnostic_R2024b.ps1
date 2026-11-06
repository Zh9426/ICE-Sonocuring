param([switch]$TestsOnly)
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'results/kwave_offaxis_diagnostic_2026-10-22'
$runTmp=Join-Path $PSScriptRoot 'tmp'
New-Item -ItemType Directory -Force -Path $out,$runTmp | Out-Null
$priorTemp=$env:TEMP; $priorTmp=$env:TMP
try {
    $env:TEMP=$runTmp; $env:TMP=$runTmp
    $expression='verify_kwave_offaxis_diagnostic;'
    if (-not $TestsOnly) { $expression+=' run_kwave_offaxis_diagnostic;' }
    $logPrefix=if ($TestsOnly) { 'tests' } else { 'solver' }
    $logPath=Join-Path $out ($logPrefix+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
    Write-Host "MATLAB log: $logPath"
    & 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe' -wait -nosplash -sd $PSScriptRoot -batch $expression -logfile $logPath
    if ($LASTEXITCODE -ne 0) { throw "Off-axis diagnostic failed: $LASTEXITCODE" }
} finally {
    $env:TEMP=$priorTemp; $env:TMP=$priorTmp
}
