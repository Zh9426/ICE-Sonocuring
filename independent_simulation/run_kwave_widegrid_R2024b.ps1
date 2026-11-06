param([switch]$TestsOnly,[ValidateSet('probe','even32','full64_matched')][string]$Case='probe')
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'results/kwave_widegrid_2026-10-24'
$runTmp=Join-Path $PSScriptRoot 'tmp'
New-Item -ItemType Directory -Force -Path $out,$runTmp | Out-Null
$priorTemp=$env:TEMP; $priorTmp=$env:TMP
try {
    $env:TEMP=$runTmp; $env:TMP=$runTmp
    if ($TestsOnly) { $expression='verify_widegrid;' }
    else { $expression="run_kwave_widegrid('$Case');" }
    $log=Join-Path $out ('run_'+$Case+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
    & 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe' -wait -nosplash -sd $PSScriptRoot -batch $expression -logfile $log
    if ($LASTEXITCODE -ne 0) { throw "Wide-grid job failed: $LASTEXITCODE" }
} finally { $env:TEMP=$priorTemp; $env:TMP=$priorTmp }
