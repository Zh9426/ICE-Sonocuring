function tests=test_point_target
tests=functiontests(localfunctions);
end

function testRoundTripTime(t)
c=iceind.default_config(); c.probe.element_x_m=0;
d=iceind.simulate_rf(c);
[~,k]=max(abs(d.rf(:,1)));
verifyLessThanOrEqual(t,abs(d.time_s(k)-2*c.target.xz_m(2)/c.medium.c_m_s),1/c.sampling.fs_hz);
end

function testCenteredSymmetry(t)
c=iceind.default_config(); c.target.xz_m=[0 .020];
d=iceind.simulate_rf(c);
verifyEqual(t,d.rf,fliplr(d.rf),'AbsTol',1e-12);
end

function testOffGridLocalization(t)
c=iceind.default_config(); c.target.xz_m=[.00083 .02003];
d=iceind.simulate_rf(c); b=iceind.reconstruct(d,c);
verifyLessThanOrEqual(t,norm(b.peak_xz_m-c.target.xz_m), ...
    hypot(diff(c.image.x_m(1:2)),diff(c.image.z_m(1:2))));
verifyGreaterThan(t,max(b.envelope(:)),0);
end

function testSamplingRejected(t)
c=iceind.default_config(); c.sampling.fs_hz=c.pulse.fc_hz;
verifyError(t,@()iceind.simulate_rf(c),'iceind:Sampling');
end

function testTruncatedAcquisitionRejected(t)
c=iceind.default_config(); c.sampling.duration_s=10e-6;
verifyError(t,@()iceind.simulate_rf(c),'iceind:Acquisition');
end
