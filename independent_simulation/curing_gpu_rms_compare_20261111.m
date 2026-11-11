function comparison=curing_gpu_rms_compare_20261111()
%CURING_GPU_RMS_COMPARE_20261111 Compare CPU/GPU all-grid peak and RMS.
% Reuses the prior small non-cubic 320-step point-source CPU diagnostic.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
bin=fullfile(root,'dependencies','kwave-cuda-unified-v1.4.2');
prior=fullfile(root,'results','curing_field_2026-11-10','qp_rms_probe');
out=fullfile(root,'results','curing_field_2026-11-10','gpu_rms_compare_20261111');
assert(~isfolder(out),'iceind:NoOverwrite','Inspect existing comparison output.'); mkdir(out);
n=[24 20 16]; dx=100e-6; g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
g.setTime(320,.2*dx/1540); medium=struct('sound_speed',1540,'density',1000);
source=struct(); source.p_mask=false(n); source.p_mask(7,8,4)=true;
source.p=single(sin(2*pi*6e6*g.t_array).*(g.t_array<20/6e6)); source.p_mode='additive';
sensor=struct(); sensor.mask=true(n); sensor.record={'p_rms','p_max_all','p_min_all','p_final'};
comparison=struct('start_index',{},'sample_count',{},'qp_relative_l2',{}, ...
    'pmax_relative_l2',{},'pmin_relative_l2',{},'gpu_s',{},'p_source_mode',{});
for start=[1 37]
    sensor.record_start_index=start;
    c=load(fullfile(prior,sprintf('fullmask_start%d.mat',start)),'data'); cpu=c.data;
    sub=fullfile(out,sprintf('start%d',start)); mkdir(sub); tic;
    gpu=kspaceFirstOrder3DG(g,medium,source,sensor,'PMLInside',false,'PMLSize',8, ...
        'PlotSim',false,'BinaryPath',bin,'BinaryName','kspaceFirstOrder-CUDA-windows.exe', ...
        'DataPath',sub,'DataName','rms_probe','DeleteData',false,'DeviceNum',0,'VerboseLevel',1); elapsed=toc;
    assert(numel(gpu.p_rms)==prod(n) && isequal(size(gpu.p_max_all),n) && ...
        isequal(size(gpu.p_min_all),n),'iceind:GPUValidation','Unexpected output dimensions.');
    count=g.Nt-start+1;
    qcpu=double(cpu.p_rms(:)).^2*count*g.dt; qgpu=double(gpu.p_rms(:)).^2*count*g.dt;
    mode=h5read(fullfile(sub,'rms_probe_input.h5'),'/p_source_mode');
    assert(mode==2,'iceind:GPUValidation','Unexpected source mode.');
    comparison(end+1)=struct('start_index',start,'sample_count',count, ...
        'qp_relative_l2',rel(qcpu,qgpu), ...
        'pmax_relative_l2',rel(double(cpu.p_max_all),double(gpu.p_max_all)), ...
        'pmin_relative_l2',rel(double(cpu.p_min_all),double(gpu.p_min_all)), ...
        'gpu_s',elapsed,'p_source_mode',double(mode)); %#ok<AGROW>
end
writetable(struct2table(comparison),fullfile(out,'comparison.csv')); disp(struct2table(comparison));
end
function x=rel(a,b)
x=norm(a(:)-b(:))/norm(a(:));
end
