function out=curing_field_run(action,varargin)
%CURING_FIELD_RUN Entry point for the 2026-11-10 CPU feasibility/sensitivity run.
% Actions: estimate | export | audit | probe | run | compare | all
% MATLAB R2024a (user-specified), CPU only, no VSX/activation/hardware.
% Every numerical claim must come from an executed call; the estimate action is
% explicitly an unmeasured projection.
if nargin<1 || isempty(action), action='all'; end
p=inputParser; p.addParameter('maxHours',8,@isscalar);
p.addParameter('steps',64,@isscalar);
p.parse(varargin{:}); opt=p.Results;
root=fileparts(mfilename('fullpath'));
assert(strcmp(version('-release'),'2024a'),'iceind:CuringFieldMATLAB', ...
    'This entry is bound to MATLAB R2024a per the user instruction; found %s.',version('-release'));
old=path; cleanup=onCleanup(@()path(old));
addpath(root);
kw=curing_field_kwave_root(root);
addpath(kw,'-begin');
outdir=fullfile(root,'results','curing_field_2026-11-10');
if ~isfolder(outdir), mkdir(outdir); end
switch lower(action)
    case 'estimate'
        out=do_estimate(outdir,false);
    case 'export'
        out=iceind.curing_field_export_drivers(fullfile(outdir,'drivers'));
    case 'audit'
        man=load_manifest(outdir);
        out=iceind.curing_field_source_audit(man,fullfile(outdir,'source_audit'));
    case 'probe'
        man=load_manifest(outdir);
        out=do_probe(man,outdir,opt.steps);
    case 'run'
        error('iceind:CuringFieldNotReady', ...
            'Full runs are disabled: BLI propagation and Qp capture remain unvalidated.');
    case 'compare'
        out=iceind.curing_field_compare(outdir);
    case 'all'
        error('iceind:CuringFieldNotReady', ...
            'Full runs are disabled: BLI propagation and Qp capture remain unvalidated.');
    otherwise
        error('iceind:CuringFieldAction','Unknown action: %s',action);
end
end
function kw=curing_field_kwave_root(root)
cand={fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'), ...
      fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1')};
for k=1:numel(cand)
    if isfile(fullfile(cand{k},'kspaceFirstOrder3D.m')), kw=cand{k}; return; end
end
error('iceind:CuringFieldDependency','k-Wave 1.4.1 toolbox not found under dependencies/.');
end
function man=load_manifest(outdir)
f=fullfile(outdir,'drivers','driver_manifest.json');
assert(isfile(f),'iceind:CuringField','Run the export action first.');
man=jsondecode(fileread(f));
end
function r=driver_for(man,variant)
k=find(strcmp({man.rows.name},variant));
assert(numel(k)==1,'iceind:CuringField','No exported driver for %s.',variant);
r=man.rows(k);
end
function e=do_estimate(outdir,measured)
cases=iceind.curing_field_cases();
rows=struct('tag',{},'grid_size',{},'Nt',{},'dt_s',{},'voxels_with_pml',{}, ...
    'point_steps',{},'memory_bytes',{},'projected_s',{},'gate',{});
for k=1:numel(cases)
    est=iceind.curing_field_estimate(cases(k));
    r=struct('tag',est.tag,'Nt',est.Nt, ...
        'dt_s',est.dt_s,'voxels_with_pml',est.voxels_with_pml, ...
        'point_steps',est.point_steps,'memory_bytes',est.memory_bytes, ...
        'projected_s',est.projected_s,'gate',est.gate);
    r.grid_size=est.grid_size;
    rows(end+1)=r; %#ok<AGROW>
end
e=struct('schema_version',1,'action','estimate', ...
    'measured',measured,'generated_local',datestr(now,30), ...
    'matlab',version,'computer',computer, ...
    'note',['Projections require measured rate/bytes; NaN means not measured. ' ...
        'This action never solves the wave equation.']);
e.rows=rows;
f=fullfile(outdir,'pre_solve_estimate.json');
if isfile(f), e=jsondecode(fileread(f)); else, iceind.curing_field_write_json(f,e); end
disp(struct2table(rows));
end
function probe=do_probe(man,outdir,steps)
cases=iceind.curing_field_cases();
grids=unique([cases.dx_m]);
probe=struct('rows',{{}});
for g=1:numel(grids)
    k=find([cases.dx_m]==grids(g),1);
    tag=sprintf('dx%02dum',round(grids(g)*1e6));
    f=fullfile(outdir,['probe_' tag '.json']);
    if isfile(f)
        r=jsondecode(fileread(f));
    else
        c=cases(k); m=driver_for(man,c.variant);
        fprintf('PROBE %s (%d steps, full grid)\n',tag,steps);
        r=iceind.curing_field_probe(c,m.mat,steps);
        iceind.curing_field_write_json(f,r);
    end
    probe.rows{end+1}=r;
end
end
function status=do_run(man,outdir,maxHours)
cases=iceind.curing_field_cases();
budget=maxHours*3600;
% Conservative planning values: worst measured rate and worst bytes/voxel.
rates=[]; bytes=[]; grids=unique([cases.dx_m]);
for gi=grids
    f=fullfile(outdir,sprintf('probe_dx%02dum.json',round(gi*1e6)));
    if isfile(f)
        r=jsondecode(fileread(f)); rates(end+1)=r.rate_point_steps_per_s; bytes(end+1)=r.bytes_per_voxel; %#ok<AGROW>
    end
end
assert(numel(rates)==numel(grids),'iceind:CuringField', ...
    'Complete the probe for every grid before propagation.');
rate=min(rates); bytes=max(bytes);
spent=0; deferred={}; ran={};
for k=1:numel(cases)
    c=cases(k);
    f=fullfile(outdir,[c.tag '_metrics.json']);
    if isfile(f), continue; end
    est=iceind.curing_field_estimate(c,rate,bytes);
    projected=est.projected_s;
    if ~isfinite(projected) || projected>budget-spent
        deferred{end+1}=struct('tag',c.tag,'projected_s',projected, ...
            'reason','projected CPU time exceeds remaining budget; not started'); %#ok<AGROW>
        fprintf('DEFER %s projected %.0f s (remaining %.0f s)\n',c.tag,projected,budget-spent);
        continue
    end
    m=driver_for(man,c.variant);
    report=iceind.curing_field_run_case(c,m.mat,maxHours);
    ran{end+1}=c.tag; spent=spent+report.runtime_s; %#ok<AGROW>
end
status=struct('schema_version',1,'budget_s',budget,'spent_s',spent, ...
    'rate_point_steps_per_s',rate, ...
    'bytes_per_voxel',bytes,'generated_local',datestr(now,30));
status.ran=ran;
status.deferred=deferred;
f=fullfile(outdir,['run_status_' datestr(now,30) '.json']);
iceind.curing_field_write_json(f,status);
if isempty(ran) && ~isempty(deferred)
    block=struct('status','blocked_by_projected_cpu_time', ...
        'reason','No full propagation was started; the measured projection exceeds the budget.', ...
        'budget_s',budget,'rate_point_steps_per_s',rate,'bytes_per_voxel',bytes, ...
        'generated_local',datestr(now,30), ...
        'note','No field/metric artifact was produced. This is a resource block, not a numerical result.');
    block.deferred=deferred;
    iceind.curing_field_write_json(fullfile(outdir,['feasibility_block_' datestr(now,30) '.json']),block);
end
end
