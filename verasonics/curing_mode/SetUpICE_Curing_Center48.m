function [seq,report,cfg]=SetUpICE_Curing_Center48(cfg,outdir)
%SETUPICE_CURING_CENTER48 Central 48 physical ranks, standalone TX-only.
if nargin<1 || isempty(cfg), cfg=icec.default_config(); end
if nargin<2, outdir=[]; end
cfg.partition.exposure_ranks=9:56;
[seq,report,cfg]=SetUpICE_CuringOnly(cfg,outdir);
end
