function report=run_kwave_field(sequence,txIndex,dx)
%RUN_KWAVE_FIELD Actual 3-D propagation of one compiled SetUp TX.
% Example: run_kwave_field('dual',16,64e-6)
if nargin<1, sequence='dual'; end
if nargin<2, txIndex=16; end
if nargin<3, dx=64e-6; end
root=fileparts(mfilename('fullpath'));
old=path; cleanup=onCleanup(@()path(old));
addpath(root);
kw=fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1');
assert(isfile(fullfile(kw,'kspaceFirstOrder3D.m')),'iceind:Dependency','Install documented k-Wave dependency.');
addpath(kw);
out=fullfile(root,'results','kwave');
assert(ismember(sequence,{'original','dual'}),'iceind:Sequence','Unknown sequence.');
file=fullfile(out,[sequence '_compiled.mat']);
assert(isfile(file),'iceind:Input','Run run_kwave_import first.');
loaded=load(file,'b'); b=loaded.b;
assert(ismember(txIndex,b.events.tx),'iceind:TX','TX must be referenced by Event.');
q=b.tx(txIndex); c=b.sound_speed_m_s;
% Physical lengths remain fixed across refinements. Grid centers are recorded.
L=[10.24 2.56 23.04]*1e-3; n=round(L/dx);
assert(all(abs(n*dx-L)<1e-10),'iceind:Grid','dx must divide fixed domain lengths.');
pml=round(1.28e-3/dx);
kgrid=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
sourceZ=-L(3)/2+.64e-3;
[~,iz]=min(abs(kgrid.z_vec-sourceZ));
assert(abs(kgrid.z_vec(iz)-sourceZ)<1e-12,'iceind:Grid','Source plane must align with grid.');
elementPos=b.geometry.positions_m; elementPos(:,3)=sourceZ;
% Fractional area overlap conserves each rectangle's area across grids.
weights=zeros(n(1)*n(2),size(elementPos,1),'single');
for e=1:size(elementPos,1)
    wx=max(0,min(kgrid.x_vec+dx/2,elementPos(e,1)+b.geometry.width_m/2)- ...
        max(kgrid.x_vec-dx/2,elementPos(e,1)-b.geometry.width_m/2))/dx;
    wy=max(0,min(kgrid.y_vec+dx/2,b.geometry.height_m/2)- ...
        max(kgrid.y_vec-dx/2,-b.geometry.height_m/2))/dx;
    area=wx(:)*wy(:)'; weights(:,e)=single(area(:));
end
areaError=max(abs(double(sum(weights,1))*dx^2-b.geometry.width_m*b.geometry.height_m));
assert(areaError<1e-11,'iceind:Geometry','Array clipped by grid.');
active=any(weights~=0,2);
source.p_mask=false(n); plane=false(n(1),n(2)); plane(active)=true;
source.p_mask(:,:,iz)=plane;
medium=struct('sound_speed',c,'density',1000); % density assumed; homogeneous, lossless, linear
% Max travel distance from any element to any domain corner, plus ring-down.
distance=sqrt((L(1)/2+max(abs(elementPos(:,1))))^2+(L(2)/2+b.geometry.height_m/2)^2+L(3)^2);
tEnd=max(q.delay_s)+q.duration_s+2e-6+distance/c;
kgrid.makeTime(c,.2,tEnd);
[wave,waveMeta]=iceind.kw_waveform(q,kgrid.dt,max(q.delay_s)+q.duration_s+2e-6,1);
source.p=weights(active,:)*wave; source.p_mode='additive';
sensor.mask=false(n);
requested=[0 0 20; -2 0 20; 2 0 20; 0 0 10]*1e-3;
for j=1:size(requested,1)
    [~,a]=min(abs(kgrid.x_vec-requested(j,1)));
    [~,bb]=min(abs(kgrid.y_vec-requested(j,2)));
    [~,cc]=min(abs(kgrid.z_vec-sourceZ-requested(j,3)));
    sensor.mask(a,bb,cc)=true;
end
[sx,sy,sz]=ind2sub(n,find(sensor.mask));
sensorCoordinates=[kgrid.x_vec(sx),kgrid.y_vec(sy),kgrid.z_vec(sz)-sourceZ];
sensor.record={'p','p_max','p_min','p_rms','p_max_all','p_min_all'};
cast='single'; gpuName='CPU';
if canUseGPU, dev=gpuDevice; cast='gpuArray-single'; gpuName=dev.Name; end
fprintf('Running %s TX%d: %dx%dx%d, dx %.2f um, Nt=%d, %s\n', ...
    sequence,txIndex,n,dx*1e6,kgrid.Nt,gpuName);
started=tic;
data=kspaceFirstOrder3D(kgrid,medium,source,sensor,'PMLInside',false, ...
    'PMLSize',pml,'PlotSim',false,'DataCast',cast,'DataRecast',true);
runtime=toc(started);
peak=max(abs(data.p_max_all),abs(data.p_min_all));
[~,iy0]=min(abs(kgrid.y_vec)); [~,iz20]=min(abs(kgrid.z_vec-sourceZ-.020));
z=kgrid.z_vec-sourceZ; x=kgrid.x_vec; y=kgrid.y_vec;
xz=squeeze(peak(:,iy0,:)); xy=squeeze(peak(:,:,iz20));
ix=find(abs(x)<=3e-3); iy=find(abs(y)<=1e-3); izr=find(z>=18e-3 & z<=22e-3);
roi=peak(ix,iy,izr); [roiPeak,ri]=max(roi(:)); [a,bb,cc]=ind2sub(size(roi),ri);
f=fft(double(wave(ceil(end/2),:)),2^nextpow2(size(wave,2)*2));
freq=(0:numel(f)-1)/(numel(f)*kgrid.dt); f=abs(f(1:floor(end/2)+1)).^2;
freq=freq(1:numel(f));
unsupported=sum(f(freq>c/(2*dx)))/sum(f);
report=struct('sequence',sequence,'tx_index',txIndex,'input_sha256',b.sha256, ...
    'solver','kspaceFirstOrder3D','kwave_version','1.4.1','matlab',version, ...
    'device',gpuName,'runtime_s',runtime,'dx_m',dx,'grid_size',n, ...
    'pml_cells',pml,'dt_s',kgrid.dt,'Nt',kgrid.Nt,'cfl',.2, ...
    'source_area_error_m2',areaError,'source_meta',waveMeta, ...
    'source_energy_above_grid_nyquist_fraction',unsupported, ...
    'roi_max_abs_pressure_pa_assumed',roiPeak, ...
    'roi_peak_xyz_m',[x(ix(a)) y(iy(bb)) z(izr(cc))], ...
    'target_plane_z_m',z(iz20),'physical_validation','unknown', ...
    'timing','single_event_not_full_hardware_sequence', ...
    'medium_provenance','c_existing_code_unverified_density1000_assumed_lossless', ...
    'geometry_model',b.source_geometry,'convergence','not_assessed_in_single_run');
tag=sprintf('%s_tx%d_dx%.1fum',sequence,txIndex,dx*1e6);
save(fullfile(out,[tag '.mat']),'data','report','sensorCoordinates','x','y','z','xz','xy','wave','waveMeta','-v7.3');
fid=fopen(fullfile(out,[tag '.json']),'w'); fwrite(fid,jsonencode(report,'PrettyPrint',true),'char'); fclose(fid);
fig=figure('Visible','off','Color','w','Position',[50 50 1300 750]);
figCleanup=onCleanup(@()close(fig));
tiledlayout(2,2,'Padding','compact');
nexttile; imagesc(x*1e3,z*1e3,20*log10(max(xz'/max(xz(:)),1e-3)));
axis image; ylim([0 25]); clim([-40 0]); colorbar; xlabel('x (mm)');ylabel('z (mm)');title('XZ peak |p|, normalized dB');
nexttile; imagesc(x*1e3,y*1e3,20*log10(max(xy'/max(xy(:)),1e-3)));
axis image; clim([-40 0]); colorbar;xlabel('x (mm)');ylabel('y (mm)');title('XY at z=20 mm, normalized dB');
nexttile; plot(kgrid.t_array*1e6,data.p');xlabel('Time (us)');ylabel('Pressure (Pa, assumed source)');title('Sensor pressure histories');grid on;
nexttile; plot((0:size(wave,2)-1)*kgrid.dt*1e6,wave([1 32 64],:)');
xlabel('Time (us)');ylabel('Source pressure (Pa, assumed)');title('Elements 1 / 32 / 64');grid on;
sgtitle(sprintf('k-Wave 3D | %s TX%d | dx %.1f um | uncalibrated',sequence,txIndex,dx*1e6));
exportgraphics(fig,fullfile(out,[tag '.png']),'Resolution',130);
disp(report);
end
