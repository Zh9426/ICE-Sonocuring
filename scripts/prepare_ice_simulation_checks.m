function manifest = prepare_ice_simulation_checks()
%PREPARE_ICE_SIMULATION_CHECKS Prepare simulation-only diagnostic copies.
% Does not activate Verasonics, call VSX, or execute hardware operations.
% D00163 Rev.K p18, A29, A97: simulation mode and Media wavelength units.
root=fileparts(fileparts(mfilename('fullpath')));
out=fullfile(root,'results','verification_2026-10-09');
if ~isfolder(out), mkdir(out); end
addpath(fullfile(root,'verasonics','dual_mode'));
vendor=fullfile(root,'VantageNXT-2.3.2-p2');
source=fullfile(vendor,'XJD','SetUpP9_4TSICE_FlashAngles.m');
code=fileread(source);
% Exact replacements deliberately fail if the source baseline has changed.
pairs={ ...
 'Resource.Parameters.simulateMode = 0;', ...
 sprintf('Resource.Parameters.simulateMode = 1;\nResource.Parameters.freezeOnStart = 1;\nResource.Parameters.initializeOnly = 1;'); ...
 'Resource.RcvBuffer(1).numFrames = 30;', 'Resource.RcvBuffer(1).numFrames = 1;'; ...
 'Media.function = ''movePoints'';', ...
 sprintf('Media = struct(''MP'',[0 0 80 1],''numPoints'',1,''attenuation'',-0.5);\n%% Synthetic static target: coordinates in wavelengths, not mm.'); ...
 'Receive(na*(i-1)+1).callMediaFunc = 1;', 'Receive(na*(i-1)+1).callMediaFunc = 0;'; ...
 'SeqControl(1).command = ''jump'';', 'SeqControl(1).command = ''stop'';'; ...
 'SeqControl(1).argument = 1;', 'SeqControl(1).argument = 0;'; ...
 'filename = ''MatFiles/SetUpP9_4TSICE_FlashAngles'';', ...
 ['filename = ''' strrep(fullfile(out,'ICE_baseline_point.mat'),'\','/') ''';']; ...
 'VSX;', '% VSX intentionally not called by this diagnostic copy.'};
for k=1:size(pairs,1)
    assert(isscalar(strfind(code,pairs{k,1})),'icecheck:SourceChanged', ...
        'Expected exactly one source match: %s',pairs{k,1});
    code=strrep(code,pairs{k,1},pairs{k,2});
end
copy=fullfile(out,'SetUpICE_BaselinePoint_SimOnly.m');
fid=fopen(copy,'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,code,'char'); fclose(fid);
manifest=struct('baseline_source',source,'baseline_setup_copy',copy, ...
    'baseline_status','prepared_not_executed','target_wavelengths',[0 0 80], ...
    'target_provenance','synthetic','hardware_validation','unknown', ...
    'simulation_validation','pending','modes',[]);
modes={'imaging_only','exposure_only','interleaved'};
for k=1:numel(modes)
    cfg=icevs.default_config(root); cfg.mode=modes{k};
    cfg.sequence.num_frames=1; cfg.sequence.return_every_frames=1;
    cfg.runtime.simulate_mode=1; cfg.runtime.freeze_on_start=true;
    [seq,report]=icevs.build(cfg);
    seq.Resource.Parameters.initializeOnly=1;
    seq.Media=struct('MP',[0 0 80 1],'numPoints',1,'attenuation',-.5);
    [seq.Receive.callMediaFunc]=deal(0);
    report.diagnostic=struct('target_provenance','synthetic', ...
        'target_wavelengths',[0 0 80],'initialize_only',true, ...
        'simulation_validation','pending');
    paths=icevs.save_sequence(seq,report,cfg,out);
    saved=load(paths.mat,'Resource','Media','Event','SeqControl');
    assert(saved.Resource.Parameters.simulateMode==1);
    assert(saved.Resource.Parameters.initializeOnly==1);
    assert(isequal(saved.Media.MP,[0 0 80 1]));
    assert(strcmp(saved.SeqControl(saved.Event(end).seqControl).command,'stop'));
    manifest.modes(k).mode=modes{k};
    manifest.modes(k).mat=paths.mat;
    manifest.modes(k).events=numel(seq.Event);
    manifest.modes(k).target_mm=[0 0 80]*cfg.medium.sound_speed_m_s/1000/cfg.probe.frequency_mhz;
end
fid=fopen(fullfile(out,'preparation.json'),'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(manifest,'PrettyPrint',true),'char'); fclose(fid);
disp(manifest);
end
