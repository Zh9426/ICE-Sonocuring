param([string]$MatlabPath = 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $MatlabPath)) { throw "MATLAB not found: $MatlabPath" }
$independentRoot = $PSScriptRoot
$independentTmp = Join-Path $independentRoot 'tmp'
$independentOut = Join-Path $independentRoot 'results'
New-Item -ItemType Directory -Force $independentTmp,$independentOut | Out-Null
$priorTemp = $env:TEMP
$priorTmp = $env:TMP
try {
    $env:TEMP = $independentTmp
    $env:TMP = $independentTmp
    & $MatlabPath -wait -nosplash -sd $independentRoot -batch "assert(strcmp(version('-release'),'2024b'),'Use MATLAB R2024b'); run_independent_tests; run_independent_demo;" -logfile (Join-Path $independentOut 'run_R2024b.log')
    if ($LASTEXITCODE -ne 0) { throw "Independent simulation failed; MATLAB exit code: $LASTEXITCODE" }
} finally {
    $env:TEMP = $priorTemp
    $env:TMP = $priorTmp
}
