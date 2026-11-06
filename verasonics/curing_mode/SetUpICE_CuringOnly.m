function [seq,report,cfg]=SetUpICE_CuringOnly(cfg,outdir)
%SETUPICE_CURINGONLY Build/export a standalone finite TX-only candidate.
if nargin<1 || isempty(cfg), cfg=icec.default_config(); end
if nargin<2 || isempty(outdir)
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    outdir=fullfile(root,'results','curing_only_2026-11-03','drivers');
end
[seq,report]=icec.build(cfg);
report.output_paths=icevs.save_sequence(seq,report,cfg,outdir);
fprintf('TX-only MAT saved: %s; selected=%d; no VSX/hardware execution.\n', ...
    report.output_paths.mat,report.partition.exposure_count);
end
