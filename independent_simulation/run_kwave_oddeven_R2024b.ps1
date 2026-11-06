param()
$ErrorActionPreference='Stop'
$exe='C:/Program Files/MATLAB/R2024b/bin/matlab.exe'
$out=Join-Path $PSScriptRoot 'results/kwave_oddeven'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$focusTmp=Join-Path $PSScriptRoot 'tmp'
New-Item -ItemType Directory -Force -Path $focusTmp | Out-Null
$priorTemp=$env:TEMP; $priorTmp=$env:TMP
try {
    $env:TEMP=$focusTmp; $env:TMP=$focusTmp
    & $exe -wait -nosplash -sd $PSScriptRoot -batch "run_kwave_oddeven;" -logfile (Join-Path $out 'solver.log')
    if ($LASTEXITCODE -ne 0) { throw "MATLAB k-Wave failed: $LASTEXITCODE" }
} finally {
    $env:TEMP=$priorTemp; $env:TMP=$priorTmp
}
