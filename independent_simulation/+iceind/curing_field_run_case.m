function report=curing_field_run_case(c,driverMat,maxHours)
%CURING_FIELD_RUN_CASE One full CPU propagation with a raw checkpoint first.
% Refuses to overwrite any artifact. The raw pressure-peak volume is saved
% before metrics are computed. Source model and time window are recorded.
error('iceind:CuringFieldNotReady', ...
    'Draft only: BLI propagation and Qp capture must be validated before full runs.');
if nargin<3 || isempty(maxHours), maxHours=6; end
out=c.output_dir;
if ~isfolder(out), mkdir(out); end
rawPath=fullfile(out,[c.tag '_field.mat']);
jsonPath=fullfile(out,[c.tag '_metrics.json']);
matPath=fullfile(out,[c.tag '_metrics.mat']);
assert(~isfile(rawPath) && ~isfile(jsonPath) && ~isfile(matPath), ...
    'iceind:CuringFieldNoOverwrite', ...
    'Artifact exists for %s; inspect it instead of rerunning.',c.tag);
[kg,medium,source,sensor,m]=iceind.curing_field_prepare(c,driverMat);
pml=m.pml_cells; n=m.grid_size;
assert(prod(n+2*pml)*4*8 < available_bytes(),'iceind:CuringFieldMemory', ...
    'Conservative pre-check failed; use a smaller domain.');
fprintf('BEGIN %s | grid %dx%dx%d | Nt=%d | dt=%.4g ns | active=%d\n', ...
    c.tag,n(1),n(2),n(3),kg.Nt,kg.dt*1e9,m.num_active);
base=working_set();
t0=tic;
data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
    'PlotSim',false,'DataCast','single','DataRecast',true);
elapsed=toc(t0);
peak=working_set();
x_m=kg.x_vec; y_m=kg.y_vec; z_m=kg.z_vec-m.source_z_kgrid_m; t_s=kg.t_array;
p_amp=max(data.p_max_all,-data.p_min_all);
assert(all(isfinite(p_amp),'all') && any(p_amp(:)>0),'iceind:CuringField', ...
    'Solver returned a non-finite or all-zero peak field.');
fprintf('RAW CHECKPOINT %s | %.1f s | peak %.3f Pa\n',c.tag,elapsed,double(max(p_amp,[],'all')));
p_max_all=data.p_max_all; p_min_all=data.p_min_all;
save(rawPath,'p_amp','p_max_all','p_min_all','x_m','y_m','z_m','t_s', ...
    'm','elapsed','-v7.3');
metrics=iceind.curing_field_metrics(p_amp,x_m,y_m,z_m,[0 0 20]*1e-3,c.dx_m);
report=struct('tag',c.tag,'variant',c.variant, ...
    'runtime_s',elapsed,'dt_s',kg.dt,'Nt',kg.Nt, ...
    'pml_cells',pml, ...
    'baseline_working_set_bytes',base,'peak_working_set_bytes',peak, ...
    'peak_working_set_over_baseline_bytes',peak-base, ...
    'solver','kspaceFirstOrder3D','solver_device','cpu','data_cast','single', ...
    'matlab',version,'computer',computer,'kwave_version','1.4.1', ...
    'raw_checkpoint',rawPath,'hardware_run',false,'physical_validation','unknown', ...
    'material_model','none', ...
    'limitations',{{ ...
        'Assumed homogeneous lossless fluid, flat uncalibrated rectangular pressure sources and 1 Pa reference; no voltage calibration.', ...
        'Every active element uses the same assumed source signal; total source strength therefore grows with element count and is not power matched.', ...
        'Finite domain, PML and 40 us (at least) time window; no axial/lateral convergence study here.', ...
        'Peak pressure and -6 dB volumes are not deposited acoustic energy, heating, dose, safety or cure.', ...
        'No elevation lens, coupling layer, backing, container, absorption, nonlinearity or SonoInk reaction.'}});
report.case=c;
report.source=m;
report.metrics=metrics;
report.grid_size=n;
report.grid_with_pml=n+2*pml;
save(matPath,'metrics','report','-v7.3');
iceind.curing_field_write_json(jsonPath,report);
plot_case(report,p_amp,x_m,y_m,z_m,out,c.tag);
fprintf('FINISHED %s %.1f s; forward peak %.3f Pa at [%.3f %.3f %.3f] mm\n', ...
    c.tag,elapsed,metrics.forward_peak_pa_assumed,metrics.forward_peak_xyz_m*1e3);
end
function plot_case(report,p_amp,x,y,z,out,tag)
[~,iy]=min(abs(y));
fig=figure('Visible','off','Position',[100 100 900 650]);
imagesc(x*1e3,z*1e3,squeeze(double(p_amp(:,iy,:)))');
axis image; set(gca,'YDir','normal'); xlabel('x (mm)'); ylabel('z from source plane (mm)');
title(sprintf('%s | max_t|p|, y=%.2f mm (assumed source)',strrep(tag,'_','\_'),y(iy)*1e3));
cb=colorbar; cb.Label.String='Pa (assumed)';
exportgraphics(fig,fullfile(out,[tag '_xz.png']),'Resolution',150); close(fig);
m=report.metrics;
[~,ia]=min(abs(x)); [~,ib]=min(abs(y));
zax=z*1e3; pz=double(squeeze(p_amp(ia,ib,:)));
[~,izp]=min(abs(z-m.forward_peak_xyz_m(3)));
fig=figure('Visible','off','Position',[100 100 1000 420]);
subplot(1,2,1); plot(zax,pz,'b-'); hold on;
yline(m.six_db_threshold_pa,'r--','-6 dB');
xline(m.axis_peak_z_m*1e3,'k:','peak z');
xlabel('z from source plane (mm)'); ylabel('max_t|p| (Pa)'); grid on;
title('On-axis axial profile');
subplot(1,2,2); plot(x*1e3,double(squeeze(p_amp(:,ib,izp))),'b-'); hold on;
yline(m.six_db_threshold_pa,'r--','-6 dB');
xlabel('x (mm)'); ylabel('max_t|p| (Pa)'); grid on;
title(sprintf('Lateral at z=%.2f mm',z(izp)*1e3));
exportgraphics(fig,fullfile(out,[tag '_profiles.png']),'Resolution',150); close(fig);
end
function b=working_set()
b=NaN;
try
    p=System.Diagnostics.Process.GetCurrentProcess();
    b=double(p.PeakWorkingSet64);
catch
end
end
function b=available_bytes()
b=Inf;
try
    s=memory; b=double(s.MaxPossibleArrayBytes);
catch
end
end
