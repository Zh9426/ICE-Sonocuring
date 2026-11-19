function test_steered_focus_20261119()
% Geometry and timing invariants, no propagation or hardware.
root=fileparts(mfilename('fullpath')); addpath(root);
base=load(fullfile(root,'results','curing_export_2026-11-10', ...
    'ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat'));
b=iceind.compile_kwave(base);
for angle=[0 10 -10 20 -20 30 -30]
    s=iceind.steered_focus_input_20261119(base,angle);
    q=iceind.compile_kwave(s); target=s.synthetic_target_m;
    assert(abs(norm(target)-0.02)<1e-14);
    assert(isequal(s.TW,base.TW) && isequal(s.Trans,base.Trans));
    assert(isequal(s.TX.Apod,base.TX.Apod) && nnz(s.TX.Apod)==64);
    assert(max(abs(s.ICEConfig.exposure.foci_mm-target*1e3))<1e-12);
    assert(max(abs(s.TX.FocalPt/(base.Trans.frequency*1e6)*b.sound_speed_m_s-target))<1e-12);
    arrival=q.tx.delay_s(:)+vecnorm(b.geometry.positions_m-target,2,2)/b.sound_speed_m_s;
    assert(max(arrival)-min(arrival)<1e-12);
    if angle==0
        assert(max(abs(q.tx.delay_s(:)-b.tx.delay_s(:)))<1e-12);
    else
        opposite=iceind.steered_focus_input_20261119(base,-angle);
        assert(max(abs(s.TX.Delay-fliplr(opposite.TX.Delay)))<1e-10);
    end
end
disp('PASS: 7 angles, R20, unchanged geometry/waveform/aperture, metadata, arrivals, baseline and mirrors.');
end
