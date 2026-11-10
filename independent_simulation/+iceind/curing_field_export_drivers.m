function manifest=curing_field_export_drivers(outdir)
%CURING_FIELD_EXPORT_DRIVERS Call the four user entries and export their MATs.
% The four Verasonics offline builders are invoked with simulate_mode=1 in
% their own default config; nothing is loaded into VSX and no hardware command
% is issued. Outputs go to our own curing_field_2026-11-10 directory only.
if nargin<1 || isempty(outdir)
    root=fileparts(fileparts(mfilename('fullpath')));
    outdir=fullfile(root,'results','curing_field_2026-11-10','drivers');
end
if ~isfolder(outdir), mkdir(outdir); end
manifestPath=fullfile(outdir,'driver_manifest.json');
if isfile(manifestPath)
    manifest=jsondecode(fileread(manifestPath));
    manifest=verify_existing(manifest,outdir);
    fprintf('Reusing %d exported drivers; hashes verified.\n',numel(manifest.rows));
    return
end
root=fileparts(fileparts(mfilename('fullpath')));
repo=fileparts(root);
curingDir=fullfile(repo,'verasonics','curing_mode');
assert(isfolder(curingDir),'iceind:CuringField','Missing user entry directory.');
old=path; cleanup=onCleanup(@()path(old));
addpath(curingDir);
variants=iceind.curing_field_variants();
rows=repmat(struct('name','','entry','','ranks',[],'num_active',0, ...
    'mat','','json','','events_csv','','elements_csv','','sha256','', ...
    'num_tx',0,'num_events',0,'speed_of_sound_m_s',0, ...
    'frequency_mhz',0,'active_fraction',0,'cycles',0,'foci_mm',[]),1,numel(variants));
for k=1:numel(variants)
    v=variants(k);
    fprintf('EXPORT %s via %s\n',v.name,v.entry);
    [seq,report,cfg]=feval(v.entry,[],outdir);
    paths=report.output_paths;
    assert(isequal(sort(double(cfg.partition.exposure_ranks(:)')),sort(v.ranks)), ...
        'iceind:CuringField','Exported rank mask differs from the documented entry.');
    assert(numel(seq.TX)==1 && numel(seq.TW)==1,'iceind:CuringField', ...
        'Expected one exposure TX and one parametric TW.');
    assert(all([seq.Event.rcv]==0),'iceind:CuringField', ...
        'Pure-illumination export unexpectedly contains receive events.');
    rows(k).name=v.name;
    rows(k).entry=v.entry;
    rows(k).ranks=v.ranks;
    rows(k).num_active=numel(v.ranks);
    rows(k).mat=paths.mat;
    rows(k).json=paths.json;
    rows(k).events_csv=paths.events_csv;
    rows(k).elements_csv=paths.elements_csv;
    rows(k).sha256=iceind.curing_field_sha256(paths.mat);
    rows(k).num_tx=numel(seq.TX);
    rows(k).num_events=numel(seq.Event);
    rows(k).speed_of_sound_m_s=double(seq.Resource.Parameters.speedOfSound);
    rows(k).frequency_mhz=double(seq.TW(1).Parameters(1));
    rows(k).active_fraction=double(seq.TW(1).Parameters(2));
    rows(k).cycles=double(seq.TW(1).Parameters(3))/2;
    rows(k).foci_mm=double(cfg.exposure.foci_mm);
end
manifest=struct('schema_version',1, ...
    'scope','pure-illumination offline driver exports; no VSX/hardware', ...
    'output_dir',outdir,'exported_local',datestr(now,30), ...
    'matlab_version',version);
manifest.rows=rows;
iceind.curing_field_write_json(manifestPath,manifest);
fprintf('Wrote %s\n',manifestPath);
end
function manifest=verify_existing(manifest,outdir)
for k=1:numel(manifest.rows)
    r=manifest.rows(k);
    assert(isfile(r.mat),'iceind:CuringField', ...
        'Manifest exists but driver MAT is missing: %s. Move the manifest aside to re-export.',r.mat);
    assert(strcmp(iceind.curing_field_sha256(r.mat),r.sha256),'iceind:CuringField', ...
        'Driver hash changed: %s',r.mat);
    assert(startsWith(r.mat,outdir),'iceind:CuringField','Driver outside own output directory.');
end
end
