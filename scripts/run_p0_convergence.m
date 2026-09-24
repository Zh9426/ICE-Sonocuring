function summary = run_p0_convergence(output_dir)
%RUN_P0_CONVERGENCE Limited quadrature and voxel check for synthetic dual.
% Requires run_p0_probe_compare. This is diagnostic, not a convergence
% certificate; the finite ROI and reference threshold remain unchanged.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin<1 || isempty(output_dir)
    output_dir=fullfile(root,'results','p0_probe_compare');
end
source=fullfile(output_dir,'comparison_config.mat');
if ~isfile(source)
    error('ice:P0Convergence','Run run_p0_probe_compare before this check.');
end
stored=load(source,'results','reference');
fine=stored.results{1};cfg=fine.cfg;
cfg.grid.x_m=linspace(fine.grid.x_m(1),fine.grid.x_m(end),21);
cfg.grid.y_m=linspace(fine.grid.y_m(1),fine.grid.y_m(end),15);
cfg.grid.z_m=linspace(fine.grid.z_m(1),fine.grid.z_m(end),21);
coarse=ice.simulate(cfg,stored.reference);
levels=[.25 .35 .5];
rows=cell(numel(levels),1);
for k=1:numel(levels)
    th=cfg.threshold;th.value=levels(k);
    a=ice.evaluate_threshold(coarse.exposure,coarse.target_mask, ...
        coarse.grid.voxel_volume_m3,th,cfg.source,stored.reference);
    b=ice.evaluate_threshold(fine.exposure,fine.target_mask, ...
        fine.grid.voxel_volume_m3,th,cfg.source,stored.reference);
    rows{k}=struct('relative_threshold',levels(k), ...
        'coarse_voxels',size(coarse.grid.points_m,1), ...
        'fine_voxels',size(fine.grid.points_m,1), ...
        'coarse_coverage',a.target_coverage,'fine_coverage',b.target_coverage, ...
        'coarse_off_target',a.off_target_exposure, ...
        'fine_off_target',b.off_target_exposure);
end
summary=struct2table([rows{:}]);
writetable(summary,fullfile(output_dir,'voxel_check.csv'));
points=[cfg.target.center_m;cfg.target.center_m+[0 0 -.004]];
q2=ice.solve_pressure(fine.geometry,fine.sequence.shots,points,fine.cfg);
quad_cfg=fine.cfg;quad_cfg.solver.patch_count=[4 4];
q4=ice.solve_pressure(fine.geometry,fine.sequence.shots,points,quad_cfg);
quadrature=table(points(:,1),points(:,2),points(:,3),abs(q2),abs(q4), ...
    abs(q4-q2)./max(abs(q4),eps), ...
    'VariableNames',{'x_m','y_m','z_m','pressure_2x2_pa','pressure_4x4_pa','relative_complex_error'});
writetable(quadrature,fullfile(output_dir,'surface_quadrature_check.csv'));
end
