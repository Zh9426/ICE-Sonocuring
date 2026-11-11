function results=curing_gpu_smoke_20261111()
%CURING_GPU_SMOKE_20261111 CPU/CUDA point-source launch check; not a driver field.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
bin=fullfile(root,'dependencies','kwave-cuda-unified-v1.4.2');
out=fullfile(root,'results','curing_field_2026-11-10','gpu_smoke_20261111');
assert(~isfolder(out),'iceind:NoOverwrite','Inspect existing GPU smoke output.'); mkdir(out);
dx=100e-6; g=kWaveGrid(32,dx,32,dx,32,dx); g.makeTime(1540,.2,5e-6);
medium=struct('sound_speed',1540,'density',1000);
source=struct(); source.p_mask=false(32,32,32); source.p_mask(16,16,4)=true;
source.p=single(sin(2*pi*6e6*g.t_array).*(g.t_array<20/6e6)); source.p_mode='additive';
sensor=struct(); sensor.mask=false(32,32,32); sensor.mask(16,16,10)=true;
sensor.mask(16,16,20)=true; sensor.mask(20,16,20)=true;
t=tic; cpu=kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false, ...
    'PMLSize',8,'PlotSim',false,'DataCast','single'); cpu_s=toc(t);
t=tic; gpu=kspaceFirstOrder3DG(g,medium,source,sensor,'PMLInside',false, ...
    'PMLSize',8,'PlotSim',false,'BinaryPath',bin, ...
    'BinaryName','kspaceFirstOrder-CUDA-windows.exe','DataPath',out, ...
    'DataName','point_smoke','DeleteData',false,'DeviceNum',0,'VerboseLevel',1); gpu_s=toc(t);
assert(isequal(size(cpu),size(gpu)) && all(isfinite(gpu),'all'), ...
    'iceind:GPUValidation','CPU and GPU output shapes or values invalid.');
cpu=double(cpu); gpu=double(gpu); qp_cpu=sum(cpu.^2,2)*g.dt; qp_gpu=sum(gpu.^2,2)*g.dt;
results=struct('purpose','small point-source CPU/GPU smoke only; not calibrated', ...
    'grid',[32 32 32],'nt',g.Nt,'dt_s',g.dt,'cpu_s',cpu_s,'gpu_s',gpu_s, ...
    'trace_relative_l2',norm(cpu(:)-gpu(:))/norm(cpu(:)), ...
    'qp_relative_l2',norm(qp_cpu-qp_gpu)/norm(qp_cpu), ...
    'peak_relative_error',abs(max(abs(cpu),[],'all')-max(abs(gpu),[],'all'))/max(abs(cpu),[],'all'));
time_s=g.t_array; save(fullfile(out,'smoke_traces.mat'),'cpu','gpu','time_s','qp_cpu','qp_gpu','results');
iceind.curing_field_write_json(fullfile(out,'summary.json'),results); disp(results);
end
