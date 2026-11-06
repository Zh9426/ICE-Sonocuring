function tests=test_kwave_bridge
tests=functiontests(localfunctions);
end
function s=fixture()
r=fileparts(fileparts(fileparts(mfilename('fullpath'))));
s=load(fullfile(r,'results','verasonics_dual_mode','ICE_ImagingCuring_interleaved.mat'));
end
function testCountsAndUnits(t)
s=fixture(); b=iceind.compile_kwave(s);
verifyEqual(t,height(b.events),numel(s.Event));
verifyEqual(t,sum(b.events.tx>0),750);
verifyEqual(t,b.geometry.positions_m(:,1),s.Trans.ElementPos(:,1)*1540/(6.5e6),'AbsTol',1e-14);
verifyEqual(t,b.tx(16).delay_s,s.TX(16).Delay/(6.5e6),'AbsTol',1e-15);
verifyEqual(t,b.tx(16).duration_s,20/6e6,'AbsTol',1e-15);
end
function testUnknownCommandRejected(t)
s=fixture(); s.SeqControl(1).command='triggerOut';
verifyError(t,@()iceind.compile_kwave(s),'iceind:UnsupportedControl');
end
function testUnknownWaveformRejected(t)
s=fixture(); s.TW(1).type='states';
verifyError(t,@()iceind.compile_kwave(s),'iceind:UnsupportedWaveform');
end
function testGeometryMmDoesNotChangeTXUnits(t)
s=fixture(); a=iceind.compile_kwave(s);
lambda=s.Resource.Parameters.speedOfSound/(s.Trans.frequency*1e6);
s.Trans.units='mm';
s.Trans.ElementPos(:,1:3)=s.Trans.ElementPos(:,1:3)*lambda*1e3;
s.Trans.elementWidth=s.Trans.elementWidth*lambda*1e3;
b=iceind.compile_kwave(s);
verifyEqual(t,b.geometry.positions_m,a.geometry.positions_m,'AbsTol',1e-14);
verifyEqual(t,b.tx(16).focus_m_metadata,a.tx(16).focus_m_metadata,'AbsTol',1e-14);
verifyEqual(t,b.tx(16).delay_s,a.tx(16).delay_s,'AbsTol',1e-14);
end
function testOriginalLoopBounded(t)
r=fileparts(fileparts(fileparts(mfilename('fullpath'))));
s=load(fullfile(r,'VantageNXT-2.3.2-p2','MatFiles','SetUpP9_4TSICE_FlashAngles.mat'));
b=iceind.compile_kwave(s);
verifyEqual(t,sum(b.events.tx>0),450);
verifyEqual(t,b.termination,'backward_jump_one_traversal');
verifyEqual(t,b.events.start_lower_bound_s(2),400e-6,'AbsTol',1e-14);
end
function testPWMAndFractionalDelay(t)
s=fixture(); b=iceind.compile_kwave(s); q=b.tx(16);
[signal,meta]=iceind.kw_waveform(q,1e-9,10e-6,1);
verifyEqual(t,size(signal,1),64);
verifyEqual(t,meta.half_cycles,40);
verifyEqual(t,meta.active_fraction,.67);
verifyEqual(t,meta.calibration,'assumed_not_voltage_calibrated');
verifyLessThanOrEqual(t,max(abs(signal(:))),1.001);
verifyGreaterThan(t,max(abs(signal(:))),.9);
end
