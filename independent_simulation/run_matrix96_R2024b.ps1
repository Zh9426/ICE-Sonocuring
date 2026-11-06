param([switch]$ExportOnly)
$ErrorActionPreference='Stop'
$work=$PSScriptRoot
if (-not $ExportOnly) {
    $tmp=Join-Path $work 'tmp'
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $priorTemp=$env:TEMP; $priorTmp=$env:TMP
    try {
        $env:TEMP=$tmp; $env:TMP=$tmp
        & 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe' -wait -nosplash -sd $work -batch 'run_independent_tests; run_matrix96;' -logfile (Join-Path $work 'results/matrix96_run.log')
        if ($LASTEXITCODE -ne 0) { throw 'Matrix96 MATLAB run failed; inspect log.' }
    } finally { $env:TEMP=$priorTemp; $env:TMP=$priorTmp }
}
& 'C:/Users/Zh89/anaconda3/python.exe' (Join-Path $work 'export_matrix96_view.py')
if ($LASTEXITCODE -ne 0) { throw '3D HTML export failed; MAT fields are retained.' }
