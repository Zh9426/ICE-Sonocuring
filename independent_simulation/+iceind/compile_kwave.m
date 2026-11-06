function b=compile_kwave(s)
%COMPILE_KWAVE Compile saved SetUp objects; no vendor code is executed.
% Supported: flat array, parametric TW, finite linear Event traversal.
tr=s.Trans; c=double(s.Resource.Parameters.speedOfSound);
switch tr.units
    case 'wavelengths', scale=c/(double(tr.frequency)*1e6);
    case 'mm', scale=1e-3;
    otherwise, error('iceind:Geometry','Unknown Trans units.');
end
pos=double(tr.ElementPos(:,1:3))*scale;
assert(tr.type==0 && all(pos(:,2)==0) && all(pos(:,3)==0), ...
    'iceind:Geometry','Only flat x-aligned linear arrays are supported.');
assert(all(tr.ElementPos(:,4:5)==0,'all'),'iceind:Geometry','Rotated elements unsupported.');
b.geometry=struct('positions_m',pos,'width_m',double(tr.elementWidth)*scale, ...
    'height_m',double(tr.elevationApertureMm)*1e-3,'provenance','existing_code_unverified', ...
    'elevation_focus_m_metadata',double(tr.elevationFocusMm)*1e-3, ...
    'elevation_lens_model','omitted_flat_rectangles');
b.sound_speed_m_s=c;
for k=1:numel(s.TX)
    tx=s.TX(k); w=s.TW(tx.waveform);
    assert(strcmp(w.type,'parametric'),'iceind:UnsupportedWaveform','Only parametric TW is supported.');
    p=double(w.Parameters);
    assert(numel(p)==4 && p(1)>0 && p(2)>0 && p(2)<=1 && p(3)>=1 && ...
        p(3)==fix(p(3)) && abs(p(4))==1,'iceind:Waveform','Invalid parametric waveform.');
    apod=double(tx.Apod);
    assert(numel(apod)==size(pos,1) && all(ismember(apod,[-1 0 1])), ...
        'iceind:Apod','This bridge supports only -1/0/1 Apod; PWM apodization is not silently approximated.');
    delay=double(tx.Delay)/(double(tr.frequency)*1e6);
    assert(numel(delay)==size(pos,1) && all(isfinite(delay)) && all(delay>=0), ...
        'iceind:Delay','Invalid TX.Delay.');
    b.tx(k)=struct('tx_index',k,'tw_index',tx.waveform,'frequency_hz',p(1)*1e6, ...
        'active_fraction',p(2),'half_cycles',p(3),'polarity',p(4), ...
        'duration_s',p(3)/(2*p(1)*1e6),'delay_s',delay,'apod',apod, ...
        'focus_m_metadata',double(tx.focus)*c/(double(tr.frequency)*1e6),'steer_rad_metadata',double(tx.Steer), ...
        'acoustic_center_hz',double(tr.frequency)*1e6, ...
        'bandwidth_hz',diff(double(tr.Bandwidth))*1e6);
end
allowed={'noop','timeToNextAcq','setTPCProfile','transferToHost','returnToMatlab','stop','jump'};
for k=1:numel(s.SeqControl)
    assert(ismember(s.SeqControl(k).command,allowed),'iceind:UnsupportedControl', ...
        'Unsupported SeqControl command: %s',s.SeqControl(k).command);
end
rows=struct('event_index',{},'tx',{},'rcv',{},'recon',{},'process',{}, ...
    'profile',{},'start_lower_bound_s',{},'commands',{});
clock=0; deadline=0; profile=1; b.termination='end_of_events';
for k=1:numel(s.Event)
    e=s.Event(k);
    assert(e.tx>=0 && e.tx<=numel(b.tx),'iceind:Reference','Invalid TX reference.');
    if e.tx>0, clock=max(clock,deadline); end
    ids=e.seqControl; ids=ids(ids~=0);
    assert(all(ids>=1 & ids<=numel(s.SeqControl)),'iceind:Reference','Invalid SeqControl reference.');
    rows(k)=struct('event_index',k,'tx',e.tx,'rcv',e.rcv,'recon',e.recon, ...
        'process',e.process,'profile',profile,'start_lower_bound_s',clock, ...
        'commands',strjoin({s.SeqControl(ids).command},'|'));
    finish=false;
    for j=ids
        sc=s.SeqControl(j);
        switch sc.command
            case 'noop', clock=clock+double(sc.argument)*200e-9;
            case 'timeToNextAcq'
                assert(e.tx>0,'iceind:Timing','TTNA supported only on transmit acquisitions.');
                deadline=clock+double(sc.argument)*1e-6;
            case 'setTPCProfile', profile=double(sc.argument);
            case 'stop', b.termination='stop'; finish=true;
            case 'jump'
                assert(k==numel(s.Event) && sc.argument==1,'iceind:UnsupportedControl', ...
                    'Only final jump-to-start is supported; one traversal is exported.');
                b.termination='backward_jump_one_traversal'; finish=true;
            % Host/DMA/reconstruction retained as metadata, never acoustic sources.
        end
    end
    if finish, break; end
end
b.events=struct2table(rows);
b.timing_model='explicit_commands_lower_bound_excludes_acquisition_host_latency';
b.source_amplitude='assumed_1Pa_not_voltage_calibrated';
b.source_geometry='flat_rectangular_pressure_sources_no_baffle_no_elevation_lens';
if isfield(s,'TPC'), b.TPC_metadata=s.TPC; else, b.TPC_metadata=[]; end
end
