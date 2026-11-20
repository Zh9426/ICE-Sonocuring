param(
    [string]$MatlabPath = 'C:/Program Files/MATLAB/R2024b/bin/matlab.exe',
    [ValidateSet('demo', 'steered-focus', 'steered-focus-validate')]
    [string]$Task = 'demo',
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        -not [double]::IsNaN($_) -and -not [double]::IsInfinity($_) -and
        $_ -in @(0, 10, -10, 20, -20, 30, -30)
    })]
    [double[]]$Angles = @(0, 10, -10, 20, -20, 30, -30),
    [AllowEmptyString()]
    [ValidateScript({
        $_ -ceq '' -or $_ -cmatch '\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z'
    })]
    [string]$RunTag = ''
)
$ErrorActionPreference = 'Stop'
if ($null -eq $Angles -or $Angles.Count -eq 0) { throw 'Angles must not be empty.' }
if (-not (Test-Path -LiteralPath $MatlabPath)) { throw "MATLAB not found: $MatlabPath" }
$independentRoot = $PSScriptRoot
$independentTmp = Join-Path $independentRoot 'tmp'
$independentOut = Join-Path $independentRoot 'results'
New-Item -ItemType Directory -Force $independentTmp,$independentOut | Out-Null
$priorTemp = $env:TEMP
$priorTmp = $env:TMP
$batch = "assert(strcmp(version('-release'),'2024b'),'Use MATLAB R2024b'); run_independent_tests; run_independent_demo;"
$logName = 'run_R2024b.log'
switch ($Task) {
    'steered-focus' {
        # Validation above permits only the seven numeric synthetic angles;
        # invariant formatting keeps generated MATLAB code independent of locale.
        $angleList = ($Angles | ForEach-Object {
            $_.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
        }) -join ' '
        $batch = "assert(strcmp(version('-release'),'2024b'),'Use MATLAB R2024b'); addpath(pwd); for angle_deg=[$angleList]; curing_steered_focus_gpu_20261119(angle_deg,52,false); end;"
        if ($RunTag -cne '') {
            # The validated ASCII whitelist excludes MATLAB quotes and separators.
            $batch = "setenv('ICE_STEERED_RUN_TAG','$RunTag'); " + $batch
        }
        $logName = 'run_R2024b_steered-focus.log'
    }
    'steered-focus-validate' {
        $batch = "assert(strcmp(version('-release'),'2024b'),'Use MATLAB R2024b'); addpath(pwd); test_steered_focus_20261119; test_steered_focus_metadata_20261119; test_steered_focus_output_dir_20261119; test_focus_depth_20261114;"
        $logName = 'run_R2024b_steered-focus-validate.log'
    }
}
try {
    $env:TEMP = $independentTmp
    $env:TMP = $independentTmp
    & $MatlabPath -wait -nosplash -sd $independentRoot -batch $batch -logfile (Join-Path $independentOut $logName)
    if ($LASTEXITCODE -ne 0) { throw "Independent simulation failed; MATLAB exit code: $LASTEXITCODE" }
} finally {
    $env:TEMP = $priorTemp
    $env:TMP = $priorTmp
}
