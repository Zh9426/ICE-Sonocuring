function [seq,report,cfg]=SetUpICE_Curing_Center16(cfg,outdir)
%SETUPICE_CURING_CENTER16 Central 16 physical ranks, standalone TX-only.
if nargin<1 || isempty(cfg), cfg=icec.default_config(); end
if nargin<2, outdir=[]; end
cfg.partition.exposure_ranks=25:40;
[seq,report,cfg]=SetUpICE_CuringOnly(cfg,outdir);
end
