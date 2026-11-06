param([ValidateSet('import','examples','all_original','all_dual')][string]$Task='import')
$ErrorActionPreference='Stop'
$exe='C:/Program Files/MATLAB/R2024b/bin/matlab.exe'
$work=$PSScriptRoot
$tmp=Join-Path $work 'tmp'
$out=Join-Path $work 'results/kwave'
New-Item -ItemType Directory -Force $tmp,$out | Out-Null
$command="assert(strcmp(version('-release'),'2024b')); run_independent_tests; run_kwave_import;"
switch ($Task) {
    'examples' { $command += " run_kwave_sequence('dual',16,80e-6); run_kwave_sequence('dual',16,64e-6); compare_kwave_grids; run_kwave_sequence('original',5,80e-6);" }
    'all_original' { $command += " run_kwave_sequence('original','all',64e-6);" }
    'all_dual' { $command += " run_kwave_sequence('dual','all',64e-6);" }
}
$priorTemp=$env:TEMP; $priorTmp=$env:TMP
try {
    $env:TEMP=$tmp; $env:TMP=$tmp
    & $exe -wait -nosplash -sd $work -batch $command -logfile (Join-Path $out "run_$Task.log")
    if ($LASTEXITCODE -ne 0) { throw "MATLAB failed: $LASTEXITCODE" }
} finally { $env:TEMP=$priorTemp; $env:TMP=$priorTmp }
