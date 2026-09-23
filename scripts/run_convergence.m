function report = run_convergence(cfg, output_dir)
%RUN_CONVERGENCE Surface-quadrature and voxel-center refinement evidence.
% Uses a fixed physical ROI and a fixed reference across spatial refinements.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin<1||isempty(cfg),cfg=demo_config('linear');end
if nargin<2,output_dir=fullfile(root,'results','validation');end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
g=ice.make_geometry(cfg.array);part=ice.partition_elements(g,cfg.architecture);
seq=ice.make_sequence(g,part.curing_mask,cfg);
[x,y,z]=ndgrid([-.003 0 .003],[-.002 0 .002],[.008 .015 .022]);points=[x(:),y(:),z(:)];
lambda=cfg.acoustics.sound_speed_m_s/cfg.acoustics.frequency_hz;
if isempty(cfg.solver.patch_count)
    base_count=max(1,ceil([max(g.width_m),max(g.height_m)]/(lambda/cfg.solver.patches_per_wavelength)));
else
    base_count=cfg.solver.patch_count;
end
pressure=cell(3,1);counts=zeros(3,2);
for j=1:3
    candidate=cfg;counts(j,:)=base_count*2^(j-1);candidate.solver.patch_count=counts(j,:);
    pressure{j}=ice.solve_pressure(g,seq.shots,points,candidate);
end
errors=zeros(3,1);
for j=1:3,errors(j)=norm(pressure{j}(:)-pressure{3}(:))/max(norm(pressure{3}(:)),realmin);end
quadrature=table(counts(:,1),counts(:,2),errors,'VariableNames',{'patches_x','patches_y','relative_complex_l2_to_finest'});
writetable(quadrature,fullfile(output_dir,'surface_convergence.csv'));
baseline=ice.simulate(cfg);reference=baseline.reference;grid=baseline.grid;
factors=[1 2 4];grid_rows=cell(numel(factors),1);
for j=1:numel(factors)
    factor=factors(j);
    candidate=cfg;
    if factor>1
        names={'x_m','y_m','z_m'};
        for d=1:3
            axis=grid.(names{d});step=grid.spacing_m(d)/factor;
            low=axis(1)-grid.spacing_m(d)/2;
            candidate.grid.(names{d})=low+step*((1:numel(axis)*factor)-.5);
        end
        result=ice.simulate(candidate,reference);
    else
        result=baseline;
    end
    row=ice.summary_row(result,sprintf('grid_factor_%d',factor));row.voxel_count=size(result.grid.points_m,1);
    row.dx_m=result.grid.spacing_m(1);row.dy_m=result.grid.spacing_m(2);row.dz_m=result.grid.spacing_m(3);
    grid_rows{j}=row;
end
voxel=struct2table([grid_rows{:}]);writetable(voxel,fullfile(output_dir,'voxel_convergence.csv'));
report=struct('surface',quadrature,'voxel',voxel,'cfg',cfg,'reference',reference, ...
    'interpretation','Voxel refinements report sensitivity, not a blanket convergence guarantee.');
save(fullfile(output_dir,'convergence.mat'),'report');
disp(quadrature);disp(voxel(:,{'case_name','voxel_count','target_coverage','off_target_exposure'}));
end
