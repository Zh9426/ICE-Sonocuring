function cfg=default_config(root)
%DEFAULT_CONFIG Standalone TX-only candidate, inheriting existing source values.
if nargin==0
    root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
addpath(fullfile(root,'verasonics','dual_mode'));
base=icevs.default_config(root);
cfg=rmfield(base,'imaging');
cfg.mode='exposure_only';
cfg.partition=struct('layout','exposure_only_selected','exposure_ranks',1:64, ...
    'provenance','user_standalone_curing_feasibility_2026-11-03', ...
    'exposure_selection_provenance','assumed_candidate_not_optimized');
cfg.sequence=struct('num_groups',base.sequence.num_frames);
cfg.timing=rmfield(cfg.timing,'receive_recovery_us');
end
