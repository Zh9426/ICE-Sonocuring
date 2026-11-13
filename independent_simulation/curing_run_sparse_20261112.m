function curing_run_sparse_20261112()
% Four offline GPU propagations: actual custom-rank MAT exports, two grids.
root=fileparts(mfilename('fullpath')); addpath(root);
out=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
for variant={'Odd32','Even32'}
    for dx=[65 52]
        tag=sprintf('%s_dx%d',lower(variant{1}),dx);
        raw=curing_gpu_run_case_20261111(variant{1},dx);
        curing_gpu_analyze_20261111(raw,fullfile(out,['analysis_' tag]),[0 3]);
    end
end
end
