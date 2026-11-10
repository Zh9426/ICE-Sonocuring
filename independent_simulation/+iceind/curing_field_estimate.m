function e=curing_field_estimate(c,rate_point_steps_per_s,bytes_per_voxel)
%CURING_FIELD_ESTIMATE Pre-solve grid, time-window, memory and CPU projection.
% rate and bytes must be MEASURED (small-scale probe) or left empty. With empty
% inputs the time and memory fields are NaN and the gate is 'unmeasured'; this
% function never pretends to have run a propagation.
if nargin<2, rate_point_steps_per_s=[]; end
if nargin<3, bytes_per_voxel=[]; end
n=round(c.domain_m/c.dx_m); pml=round(c.pml_m/c.dx_m);
assert(all(abs(n*c.dx_m-c.domain_m)<1e-12),'iceind:CuringField','dx must divide domain.');
assert(abs(pml*c.dx_m-c.pml_m)<1e-12,'iceind:CuringField','PML must be whole cells.');
dt=c.cfl*c.dx_m/c.sound_speed_m_s;
nt=ceil(c.minimum_end_time_s/dt)+1;
voxels=prod(n); voxelsPml=prod(n+2*pml);
pointSteps=double(voxels)*nt;
e=struct('tag',c.tag,'dx_m',c.dx_m,'pml_cells',pml,'dt_s',dt,'Nt',nt, ...
    't_end_s',(nt-1)*dt,'voxels',voxels,'voxels_with_pml',voxelsPml, ...
    'point_steps',pointSteps,'cfl',c.cfl, ...
    'solvers','kspaceFirstOrder3D (MATLAB, CPU) or kspaceFirstOrder3DC if binary present', ...
    'rate_point_steps_per_s',rate_point_steps_per_s, ...
    'bytes_per_voxel',bytes_per_voxel, ...
    'memory_bytes',NaN,'projected_s',NaN,'gate','unmeasured', ...
    'definitions',struct('point_steps','Nt * Nx*Ny*Nz physical voxels', ...
        'memory','bytes_per_voxel * prod(N+2*PML); measured probe only', ...
        'projected_time','point_steps / measured point-step rate; excludes setup/IO'));
e.grid_size=n;
e.grid_with_pml=n+2*pml;
e.domain_m=c.domain_m;
if ~isempty(bytes_per_voxel) && isfinite(bytes_per_voxel) && bytes_per_voxel>0
    e.memory_bytes=bytes_per_voxel*voxelsPml;
    available=available_memory_bytes();
    e.available_memory_bytes=available;
    if isnan(available)
        e.memory_pass=NaN;
    else
        e.memory_pass=e.memory_bytes<0.7*available;
    end
else
    e.available_memory_bytes=available_memory_bytes();
    e.memory_pass=NaN;
end
if ~isempty(rate_point_steps_per_s) && rate_point_steps_per_s>0
    e.projected_s=pointSteps/rate_point_steps_per_s;
    e.gate='measured_projection';
end
end
function b=available_memory_bytes()
% MATLAB's memory() reports the largest possible array; use it only as a bound.
try
    s=memory; b=double(s.MaxPossibleArrayBytes);
catch
    b=NaN;
end
end
