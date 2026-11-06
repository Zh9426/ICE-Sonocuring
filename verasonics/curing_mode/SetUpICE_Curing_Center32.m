function [seq,report,cfg]=SetUpICE_Curing_Center32(cfg,outdir)
%SETUPICE_CURING_CENTER32 Central 32 physical ranks, standalone TX-only.
if nargin<1 || isempty(cfg), cfg=icec.default_config(); end
if nargin<2, outdir=[]; end
cfg.partition.exposure_ranks=17:48;
[seq,report,cfg]=SetUpICE_CuringOnly(cfg,outdir);
end
