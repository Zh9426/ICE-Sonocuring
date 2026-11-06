function reports=run_matrix96(parts,c)
%RUN_MATRIX96 Independent 96-element 12x8 fixed physical partition fields.
if nargin<1,parts={'left','right'};end
if nargin<2,c=iceind.matrix96_config;end
if ischar(parts),parts={parts};end
root=fileparts(mfilename('fullpath'));old=path;guard=onCleanup(@()path(old));
addpath(root,fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
assert(strcmp(version('-release'),'2024b'),'Use MATLAB R2024b.');
out=fullfile(root,'results','matrix96');if ~isfolder(out),mkdir(out);end
reports=cell(size(parts));
for k=1:numel(parts)
    reports{k}=solveOne(parts{k},c,out);
end
end
function report=solveOne(part,c,out)
m=iceind.matrix96_model(c,part);dx=c.dx_m;n=round(c.domain_m/dx);
assert(all(abs(n*dx-c.domain_m)<1e-12),'Domain must divide grid spacing.');
g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);pml=round(c.pml_m/dx);
zs=-c.domain_m(3)/2+c.source_offset_m;[~,iz]=min(abs(g.z_vec-zs));
assert(abs(g.z_vec(iz)-zs)<1e-12,'Source must align with grid.');
x=g.x_vec;y=g.y_vec;z=g.z_vec-zs;
w=iceind.matrix96_weights(x,y,dx,m.positions_m,c.element_size_m);
w=w(:,m.active);active=any(w,2);source.p_mask=false(n);
source.p_mask(:,:,iz)=reshape(active,n(1),n(2));
distance=sqrt((c.domain_m(1)/2+max(abs(m.positions_m(:,1))))^2+ ...
    (c.domain_m(2)/2+max(abs(m.positions_m(:,2))))^2+c.domain_m(3)^2);
q=struct('frequency_hz',c.frequency_hz,'active_fraction',.67, ...
    'half_cycles',2*c.cycles,'polarity',1,'duration_s',c.cycles/c.frequency_hz, ...
    'delay_s',m.delay_s(m.active)','apod',ones(1,sum(m.active)), ...
    'bandwidth_hz',c.bandwidth_hz,'acoustic_center_hz',c.frequency_hz);
g.makeTime(c.sound_speed_m_s,c.cfl,distance/c.sound_speed_m_s+max(q.delay_s)+q.duration_s+2e-6);
[wave,waveMeta]=iceind.kw_waveform(q,g.dt,max(q.delay_s)+q.duration_s+2e-6,c.source_pressure_pa);
source.p=w(active,:)*wave;source.p_mode='additive';
requested=[c.focus_m;c.focus_m+[.002 0 0];c.focus_m+[-.002 0 0]; ...
    c.focus_m+[0 .002 0];c.focus_m+[0 -.002 0]];
sensor.mask=false(n);
for j=1:size(requested,1)
    assert(all(requested(j,:) >= [min(x),min(y),min(z)]) && ...
        all(requested(j,:) <= [max(x),max(y),max(z)]),'Sensor outside grid.');
    [~,a]=min(abs(x-requested(j,1)));[~,b]=min(abs(y-requested(j,2)));[~,d]=min(abs(z-requested(j,3)));
    sensor.mask(a,b,d)=true;
end
[a,b,d]=ind2sub(n,find(sensor.mask));sensorCoordinates=[x(a),y(b),z(d)];
sensor.record={'p','p_max_all','p_min_all'};
medium=struct('sound_speed',c.sound_speed_m_s,'density',c.density_kg_m3);
cast='single';device='CPU';
if canUseGPU
    dev=gpuDevice;device=dev.Name;cast='gpuArray-single';
    % Conservative preflight heuristic, not a guaranteed allocation bound.
    estimate=prod(n+2*pml)*4*45;
    assert(dev.AvailableMemory>estimate,'iceind:GPUMemory','Insufficient free GPU memory; keep grid unchanged.');
end
fprintf('Matrix96 %s: active=%d grid=%dx%dx%d dx=%.1fum\n',part,sum(m.active),n,dx*1e6);
clockStart=tic;
data=kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
    'PlotSim',false,'DataCast',cast,'DataRecast',true);
runtime=toc(clockStart);peak_abs=single(max(abs(data.p_max_all),abs(data.p_min_all)));
assert(all(isfinite(peak_abs(:))) && max(peak_abs(:))>0,'Invalid field.');
[~,ix]=min(abs(x-c.focus_m(1)));[~,iy]=min(abs(y-c.focus_m(2)));[~,it]=min(abs(z-c.focus_m(3)));
roiZ=find(z>=c.roi_z_m(1) & z<=c.roi_z_m(2));roi=peak_abs(:,:,roiZ);
[pk,idx]=max(roi(:));[a,b,d]=ind2sub(size(roi),idx);
edge=[reshape(roi([1 end],:,:),[],1);reshape(roi(:,[1 end],:),[],1);reshape(roi(:,:,[1 end]),[],1)];
report=struct('partition',part,'active_elements',sum(m.active),'config',c, ...
    'solver','kspaceFirstOrder3D','kwave_version','1.4.1','device',device, ...
    'runtime_s',runtime,'dt_s',g.dt,'Nt',g.Nt,'grid_size',n,'pml_cells',pml, ...
    'target_requested_m',c.focus_m,'target_sampled_m',[x(ix),y(iy),z(it)], ...
    'target_peak_pa_assumed',double(peak_abs(ix,iy,it)), ...
    'roi_peak_pa_assumed',double(pk),'roi_peak_xyz_m',[x(a),y(b),z(roiZ(d))], ...
    'roi_peak_on_boundary',a==1 || a==n(1) || b==1 || b==n(2) || d==1 || d==numel(roiZ), ...
    'minus6db_surface_touches_roi_boundary',max(edge)>=pk*10^(-6/20), ...
    'source_squared_integral_pa2_s_proxy',sum(double(wave(:)).^2)*g.dt, ...
    'physical_validation','unknown','convergence','not_established', ...
    'model','flat_rectangular_additive_pressure_sources_no_lens_no_baffle_no_coupling');
tag=sprintf('%s_dx%.1fum',part,dx*1e6);
save(fullfile(out,[tag '.mat']),'peak_abs','data','x','y','z','report','m','c','waveMeta','sensorCoordinates','-v7.3');
fid=fopen(fullfile(out,[tag '.json']),'w');fwrite(fid,jsonencode(report,'PrettyPrint',true),'char');fclose(fid);
render_matrix96(fullfile(out,[tag '.mat']));
disp(report);
end
