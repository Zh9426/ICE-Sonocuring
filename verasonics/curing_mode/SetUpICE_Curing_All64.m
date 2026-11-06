function [seq,report,cfg]=SetUpICE_Curing_All64(cfg,outdir)
%SETUPICE_CURING_ALL64 All physical ranks, standalone TX-only candidate.
if nargin<1 || isempty(cfg), cfg=icec.default_config(); end
if nargin<2, outdir=[]; end
cfg.partition.exposure_ranks=1:64;
[seq,report,cfg]=SetUpICE_CuringOnly(cfg,outdir);
end
