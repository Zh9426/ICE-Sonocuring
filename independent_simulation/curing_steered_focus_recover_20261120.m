function report=curing_steered_focus_recover_20261120(angle_deg,verify_only)
% Recover only a fully completed raw CUDA output; never rerun propagation.
% verify_only checks conversion against an existing completed MAT, no writes.
if nargin<2, verify_only=false; end
assert(ismember(angle_deg,[0 10 -10 20 -20 30 -30]));
validateattributes(verify_only,{'logical'},{'scalar'});
root=fileparts(mfilename('fullpath')); priorPath=path;
restorePath=onCleanup(@()path(priorPath)); %#ok<NASGU>
addpath(root,fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
out=iceind.steered_focus_output_dir_20261119(root,getenv('ICE_STEERED_RUN_TAG'));
if angle_deg<0, signTag='m'; else, signTag='p'; end
tag=sprintf('angle_%s%02d_dx52',signTag,abs(angle_deg));
sub=fullfile(out,[tag '_gpu_io']);
rawPath=fullfile(out,[tag '_field.mat']);
partial=fullfile(out,[tag '_field.partial.mat']);
input=fullfile(sub,'field_input.h5'); output=fullfile(sub,'field_output.h5');
assert(isfile(input) && isfile(output),'iceind:RecoveryMissing','Missing raw CUDA input or output.');
prepared=load(fullfile(sub,'preparation_metadata.mat'));
meta=prepared.meta; runtime_metadata=prepared.runtime_metadata;
target_m=prepared.target_m;
assert(angle_deg==prepared.angle_deg && norm(target_m-[sind(angle_deg) 0 cosd(angle_deg)]*.02)<1e-12);
n=double(meta.grid_size); pml=double(meta.pml_cells);
Nt=double(meta.Nt); dt_s=double(meta.dt_s);
completed_steps=double(h5read(output,'/t_index'));
assert(completed_steps==Nt && double(h5read(output,'/Nt'))==Nt, ...
    'iceind:RecoveryIncomplete','Raw CUDA output did not finish the full time window.');
assert(strcmp(local_attr(output,'file_type'),'output'));
assert(contains(local_attr(output,'created_by'),'CUDA'));
postTime=local_attr(output,'post-processing_phase_execution_time');
totalTime=local_attr(output,'total_execution_time');
assert(~isempty(sscanf(postTime,'%f',1)) && ~isempty(sscanf(totalTime,'%f',1)), ...
    'iceind:RecoveryIncomplete','Completed post-processing metadata is required.');
assert(isequal([double(h5read(output,'/Nx')) double(h5read(output,'/Ny')) ...
    double(h5read(output,'/Nz'))],n+2*pml));
assert(strcmp(runtime_metadata.binary_sha256, ...
    '806f20c2529c2454cef89badbfcc9c19c2360260236af5a4e98735a336899b09'));
assert(double(h5read(input,'/p_source_mode'))==2 && double(h5read(input,'/p_source_many'))==1);
assert(double(h5read(input,'/p_source_flag'))==runtime_metadata.source_samples);

start=repmat(pml+1,1,3);
p_amp=max(h5read(output,'/p_max_all',start,n),-h5read(output,'/p_min_all',start,n));
rms=h5read(output,'/p_rms');
assert(numel(rms)==prod(n));
qp=reshape(single(double(rms).^2*Nt*dt_s),n); clear rms;
p_final=h5read(output,'/p_final',start,n);
assert(isequal(size(p_amp),n) && isequal(size(qp),n) && isequal(size(p_final),n));
assert(all(isfinite(p_amp),'all') && all(isfinite(qp),'all') && all(isfinite(p_final),'all') && ...
    all(p_amp>=0,'all') && all(qp>=0,'all') && any(p_amp(:)>0));
g=kWaveGrid(n(1),meta.dx_m,n(2),meta.dx_m,n(3),meta.dx_m);
x_m=g.x_vec; y_m=g.y_vec; z_m=g.z_vec-meta.source_z_kgrid_m;
t_end_s=(Nt-1)*dt_s;
final_over_peak=max(abs(p_final),[],'all')/max(p_amp,[],'all');
report=struct('angle_deg',angle_deg,'Nt',Nt,'completed_steps',completed_steps, ...
    'existing_field_verified',false,'pressure_equal',false,'qp_equal',false, ...
    'final_equal',false,'axes_equal',false,'raw_path',rawPath);
if verify_only
    prior=load(rawPath,'p_amp','qp','p_final','x_m','y_m','z_m','dt_s','Nt');
    report.pressure_equal=isequal(p_amp,prior.p_amp);
    report.qp_equal=isequal(qp,prior.qp);
    report.final_equal=isequal(p_final,prior.p_final);
    report.axes_equal=isequal(x_m,prior.x_m) && isequal(y_m,prior.y_m) && isequal(z_m,prior.z_m);
    assert(report.pressure_equal && report.qp_equal && report.final_equal && report.axes_equal && ...
        isequal(dt_s,prior.dt_s) && isequal(Nt,prior.Nt),'iceind:RecoveryMismatch', ...
        'Recovery conversion differs from an existing completed field.');
    report.existing_field_verified=true;
    return;
end
assert(~isfile(rawPath) && ~isfile(partial),'iceind:NoOverwrite','Existing MAT or partial must not be overwritten.');
manifestPath=fullfile(sub,'stage.json'); manifest=jsondecode(fileread(manifestPath));
snapshot=fullfile(sub,'stage_before_recovery_20261120.json');
assert(~isfile(snapshot),'iceind:NoOverwrite','Recovery snapshot already exists.');
copyfile(manifestPath,snapshot);
recovered=char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
elapsed=sscanf(totalTime,'%f',1); started=manifest.started;
runtime_metadata.p_source_mode=2; runtime_metadata.p_source_many=1;
runtime_metadata.recovery=struct('converted_at',recovered,'completed_steps',completed_steps, ...
    'evidence','full t_index=Nt and completed post-processing/total-time attributes; validated against +20 field', ...
    'output_sha256',iceind.curing_field_sha256(output), ...
    'elapsed_scope','CUDA total header time; excludes resumed MATLAB conversion');
notes=['Recovered from completed original CUDA output; no new propagation. ' ...
    'Synthetic, uncalibrated pressure and Qp proxy; no elevation lens or cure/safety validation.'];
save(partial,'p_amp','qp','p_final','x_m','y_m','z_m','target_m','angle_deg', ...
    'meta','runtime_metadata','dt_s','Nt','t_end_s','elapsed','started','final_over_peak','notes','-v7.3');
[ok,msg]=movefile(partial,rawPath); assert(ok,'iceind:RecoverySave','Rename failed: %s',msg);
manifest.stage='complete'; manifest.recovered_at=recovered;
manifest.recovered_from_completed_cuda_output=true; manifest.elapsed_s=elapsed;
manifest.elapsed_scope=runtime_metadata.recovery.elapsed_scope;
manifest.raw_path=rawPath; manifest.updated=recovered;
fid=fopen(manifestPath,'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(manifest,PrettyPrint=true),'char');
fprintf('Recovered %s from completed raw CUDA output.\n',rawPath);
end

function value=local_attr(filename,name)
value=h5readatt(filename,'/',name);
if iscell(value), value=value{1}; end
value=reshape(char(value),1,[]);
value(value==char(0))=[];
value=strtrim(value);
end
