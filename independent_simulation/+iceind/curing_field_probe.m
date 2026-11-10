function probe=curing_field_probe(c,driverMat,steps)
%CURING_FIELD_PROBE Short full-grid CPU solve to measure rate and peak memory.
% The source is truncated to `steps` samples; this is a resource probe, not a
% physical field result and must never be reported as propagation evidence.
if nargin<3 || isempty(steps), steps=64; end
[kg,medium,source,sensor,m]=iceind.curing_field_prepare(c,driverMat);
steps=min(steps,kg.Nt);
kg.setTime(steps,kg.dt);
source.p=source.p(:,1:steps);
pml=m.pml_cells; n=m.grid_size;
base=working_set();
t0=tic;
data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
    'PlotSim',false,'DataCast','single','DataRecast',true);
elapsed=toc(t0);
peak=working_set();
rate=double(prod(n))*steps/elapsed;
% PeakWorkingSet64 is a process lifetime high-water mark; subtracting two
% readings does not measure this solver's allocation. Leave it unknown.
bytesPerVoxel=NaN;
probe=struct('tag',c.tag,'purpose','Resource probe only; truncated source/time; not a field result.', ...
    'grid_size',n,'grid_with_pml',n+2*pml,'pml_cells',pml, ...
    'dt_s',kg.dt,'steps',steps,'t_end_s',kg.t_array(end), ...
    'runtime_s',elapsed,'rate_point_steps_per_s',rate, ...
    'peak_working_set_bytes',peak,'baseline_working_set_bytes',base, ...
    'bytes_per_voxel',bytesPerVoxel,'solver','kspaceFirstOrder3D', ...
    'solver_device','cpu','data_cast','single','matlab',version, ...
    'computer',computer,'cpu',cpu_identity(),'kwave_version','1.4.1', ...
    'memory_note','Lifetime peak readings cannot determine solver bytes per voxel.', ...
    'generated_local',datestr(now,30));
end
function b=working_set()
b=NaN;
try
    p=System.Diagnostics.Process.GetCurrentProcess();
    b=double(p.PeakWorkingSet64);
catch
end
end
function s=cpu_identity()
s=struct('identifier',getenv('PROCESSOR_IDENTIFIER'), ...
    'cores',feature('numcores'),'arch',computer);
end
