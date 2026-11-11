function comparison=curing_gpu_bli_cpu_compare_20261111()
%CURING_GPU_BLI_CPU_COMPARE_20261111 Reproduce prior BLI single-element CPU runs on GPU.
% Two grids, same five points and 6 MHz diagnostic sine. No real probe claim.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
bin=fullfile(root,'dependencies','kwave-cuda-unified-v1.4.2');
prior=fullfile(root,'results','curing_field_2026-11-10','bli_propagation_probe');
out=fullfile(root,'results','curing_field_2026-11-10','gpu_bli_cpu_compare_20261111');
assert(~isfolder(out),'iceind:NoOverwrite','Inspect existing comparison output.'); mkdir(out);
domain=[6.5 5.2 10.4]*1e-3; zoffset=.52e-3;
points=[0 0 2.08;0 0 5.2;0 0 7.8;1.04 0 2.08;1.04 0 5.2]*1e-3;
comparison=struct('dx_um',{},'trace_l2',{},'qp_l2',{},'peak_relative_error',{}, ...
    'time_samples',{},'elapsed_s',{},'p_source_mode',{});
for dx=[65e-6 52e-6]
    n=round(domain/dx); g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
    g.makeTime(1540,.2,14e-6); z0=-domain(3)/2+zoffset;
    a=kWaveArray('BLITolerance',.05,'UpsamplingRate',10);
    a.addRectElement([-65e-6 0 z0],.11e-3,2.02e-3,[0 0 0]);
    weights=a.getElementGridWeights(g,1); source=struct(); source.p_mask=weights~=0;
    wave=single(sin(2*pi*6e6*g.t_array).*(g.t_array<20/6e6));
    source.p=single(weights(source.p_mask))*wave; source.p_mode='additive';
    sensor=struct(); sensor.mask=false(n);
    for j=1:size(points,1)
        [~,ix]=min(abs(g.x_vec-points(j,1))); [~,iy]=min(abs(g.y_vec-points(j,2)));
        [~,iz]=min(abs(g.z_vec-(z0+points(j,3)))); sensor.mask(ix,iy,iz)=true;
    end
    [ix,iy,iz]=ind2sub(n,find(sensor.mask)); sensorXYZ=[g.x_vec(ix),g.y_vec(iy),g.z_vec(iz)-z0];
    previous=load(fullfile(prior,sprintf('single_element_dx%02d_trace.mat',round(dx*1e6))), ...
        'traces','time_s','sensorXYZ');
    assert(isequal(size(previous.sensorXYZ),size(sensorXYZ)) && ...
        max(abs(previous.sensorXYZ-sensorXYZ),[],'all')<1e-12 && ...
        numel(previous.time_s)==g.Nt && max(abs(previous.time_s-g.t_array))<1e-15, ...
        'iceind:GPUValidation','Prior CPU geometry/time differs.');
    sub=fullfile(out,sprintf('dx%d',round(dx*1e6))); mkdir(sub);
    medium=struct('sound_speed',1540,'density',1000); tic;
    gpu=kspaceFirstOrder3DG(g,medium,source,sensor,'PMLInside',false, ...
        'PMLSize',round(1.04e-3/dx),'PlotSim',false,'BinaryPath',bin, ...
        'BinaryName','kspaceFirstOrder-CUDA-windows.exe','DataPath',sub, ...
        'DataName','bli_probe','DeleteData',false,'DeviceNum',0,'VerboseLevel',1); elapsed=toc;
    cpu=double(previous.traces); gpu=double(gpu);
    assert(isequal(size(cpu),size(gpu)) && all(isfinite(gpu),'all'), ...
        'iceind:GPUValidation','Invalid GPU trace shape or values.');
    qcpu=sum(cpu.^2,2)*g.dt; qgpu=sum(gpu.^2,2)*g.dt;
    mode=h5read(fullfile(sub,'bli_probe_input.h5'),'/p_source_mode');
    assert(mode==2,'iceind:GPUValidation','Unexpected pressure source mode.');
    comparison(end+1)=struct('dx_um',round(dx*1e6), ...
        'trace_l2',norm(cpu(:)-gpu(:))/norm(cpu(:)), ...
        'qp_l2',norm(qcpu-qgpu)/norm(qcpu), ...
        'peak_relative_error',abs(max(abs(cpu),[],'all')-max(abs(gpu),[],'all'))/max(abs(cpu),[],'all'), ...
        'time_samples',g.Nt,'elapsed_s',elapsed,'p_source_mode',double(mode)); %#ok<AGROW>
    time_s=g.t_array; save(fullfile(sub,'gpu_trace.mat'),'gpu','time_s','sensorXYZ','qgpu','-v7.3');
end
writetable(struct2table(comparison),fullfile(out,'comparison.csv')); disp(struct2table(comparison));
end
