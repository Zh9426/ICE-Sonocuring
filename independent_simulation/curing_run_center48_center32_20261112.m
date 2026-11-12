function curing_run_center48_center32_20261112()
% Four offline GPU propagations, same assumptions as All64/Center16.
root=fileparts(mfilename('fullpath')); addpath(root);
out=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
variants={'Center48','Center32'}; grids=[65 52];
for i=1:numel(variants)
    for j=1:numel(grids)
        tag=sprintf('%s_dx%d',lower(variants{i}),grids(j));
        raw=curing_gpu_run_case_20261111(variants{i},grids(j));
        curing_gpu_analyze_20261111(raw,fullfile(out,['analysis_' tag]),[0 3]);
    end
end
end
