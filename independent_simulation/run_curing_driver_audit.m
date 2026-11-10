% run_curing_driver_audit.m
% Offline entry point for the independent curing-driver audit.
% Builds/exports the four SetUpICE_Curing_* variants into a fresh results
% directory, reloads every MAT, and fails with a nonzero status if any check
% fails. It does not call VSX, activate a system, or touch hardware.

thisFile = mfilename('fullpath');
if isempty(thisFile)
    indepRoot = pwd;
else
    indepRoot = fileparts(thisFile);
end
addpath(indepRoot);

outroot = getenv('ICE_CURING_AUDIT_OUT');
fprintf('AUDIT wrapper: independent_simulation=%s\n',indepRoot);
if isempty(outroot)
    fprintf('AUDIT wrapper: ICE_CURING_AUDIT_OUT unset; using timestamped directory.\n');
else
    fprintf('AUDIT wrapper: ICE_CURING_AUDIT_OUT=%s\n',outroot);
end

summary = iceind.audit_curing_drivers(outroot);

fprintf('AUDIT_STATUS all_passed=%d checks=%d failed=%d\n', ...
    summary.all_passed,summary.checks_total,summary.checks_failed);
fprintf('AUDIT_STATUS outdir=%s\n',summary.outdir);
fprintf('AUDIT_STATUS matlab=%s\n',summary.matlab_version);

if ~summary.all_passed
    error('iceind:Audit','%d audit check(s) failed; results retained in %s', ...
        summary.checks_failed,summary.outdir);
end
