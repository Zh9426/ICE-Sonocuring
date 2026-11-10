param([string]$MatlabPath = 'E:/MATLAB/bin/matlab.exe')
# Offline curing-driver export/readback audit.
# Calls only the four SetUpICE_Curing_* MATLAB entry points; no VSX, activate,
# simulator load, or hardware operation is performed by this script.
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $MatlabPath)) { throw "MATLAB not found: $MatlabPath" }
$independentRoot = $PSScriptRoot
$tmpDir = Join-Path $independentRoot 'tmp'
$resultsRoot = Join-Path $independentRoot 'results'
New-Item -ItemType Directory -Force $tmpDir,$resultsRoot | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $resultsRoot ('curing_driver_audit_' + $stamp)
New-Item -ItemType Directory -Force $outDir | Out-Null
$logFile = Join-Path $tmpDir ('curing_driver_audit_' + $stamp + '.log')

$priorTemp = $env:TEMP
$priorTmp = $env:TMP
$priorOut = $env:ICE_CURING_AUDIT_OUT
try {
    $env:TEMP = $tmpDir
    $env:TMP = $tmpDir
    $env:ICE_CURING_AUDIT_OUT = $outDir
    & $MatlabPath -wait -nosplash -sd $independentRoot -batch "run_curing_driver_audit" -logfile $logFile
    $code = $LASTEXITCODE
    if (Test-Path -LiteralPath $logFile) {
        Copy-Item -LiteralPath $logFile -Destination (Join-Path $outDir 'matlab_console.log')
    }
    if ($code -ne 0) {
        throw "Curing driver audit failed; MATLAB exit code: $code. Results: $outDir"
    }
    Write-Output "AUDIT PASS: $outDir"
} finally {
    $env:TEMP = $priorTemp
    $env:TMP = $priorTmp
    $env:ICE_CURING_AUDIT_OUT = $priorOut
}
