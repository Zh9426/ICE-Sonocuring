function [seq,report,cfg] = SetUpICE_ImagingCuring(cfg,outdir)
%SETUPICE_IMAGINGCURING Offline build/export of the ICE dual-mode prototype.
%   [seq,report,cfg] = SetUpICE_ImagingCuring();
%   cfg = icevs.default_config(); cfg.exposure.foci_mm = [-1 0 20;1 0 20];
%   [seq,report] = SetUpICE_ImagingCuring(cfg,'results/my_sequence');
% No activation, VSX, acquisition, or voltage-setting call occurs here.
if nargin<1 || isempty(cfg), cfg=icevs.default_config(); end
if nargin<2 || isempty(outdir)
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    folder='verasonics_original_sector';
    if strcmp(cfg.partition.layout,'full64_imaging_selected_exposure')
        folder='verasonics_full64_selected_exposure';
    end
    if strcmp(cfg.partition.layout,'left_imaging_right_exposure') && ...
            ~strcmp(cfg.imaging.geometry,'original_sector')
        folder='verasonics_linear64_partition';
    end
    outdir=fullfile(root,'results',folder);
end
[seq,report]=icevs.build(cfg);
paths=icevs.save_sequence(seq,report,cfg,outdir);
report.output_paths=paths;
fprintf('Offline sequence saved: %s\n',paths.mat);
fprintf('Mode: %s; finite exposure pulses: %d; physical validation: unknown.\n', ...
    cfg.mode,report.timing.total_exposure_pulses);
end
