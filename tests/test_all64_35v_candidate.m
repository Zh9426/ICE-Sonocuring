function tests=test_all64_35v_candidate
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
addpath(fullfile(t.TestData.root,'verasonics','curing_mode'));
end
function testCandidateIsFiniteOfflineAndPreservesUnknownLimits(t)
[s,r,c]=icec.all64_35v_candidate();
verifyEqual(t,c.exposure.voltage_v,35);
verifyEqual(t,c.probe.max_high_voltage_v,35);
verifyEqual(t,c.exposure.foci_mm,[0 0 20]);
verifyEqual(t,sum(s.TX.Apod>0),64);
verifyEqual(t,s.TPC(1).hv,35);
verifyEqual(t,c.exposure.tpc_profile,1);
verifyEqual(t,c.runtime.simulate_mode,1);
verifyTrue(t,all(isnan([c.hardware_limits.max_burst_us,c.hardware_limits.max_local_duty_cycle,c.hardware_limits.max_total_on_time_us])));
verifyFalse(t,r.operating_envelope.hardware_qualified);
verifyEqual(t,s.SeqControl(s.Event(end).seqControl).command,'stop');
verifyFalse(t,any(strcmp({s.SeqControl.command},'jump')));
end
