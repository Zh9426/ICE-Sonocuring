function test_focus_depth_20261114()
root=fileparts(mfilename('fullpath')); addpath(root);
base=load(fullfile(root,'results','curing_export_2026-11-10','ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat'));
b=iceind.compile_kwave(base);
for depth=[16 18 20 22]
    s=iceind.focus_depth_input_20261114(base,depth);
    q=iceind.compile_kwave(s);
    assert(isequal(s.TW,base.TW) && isequal(s.Trans,base.Trans));
    assert(isequal(s.TX.Apod,base.TX.Apod));
    d=vecnorm(b.geometry.positions_m-[0 0 depth*1e-3],2,2);
    arrival=q.tx.delay_s(:)+d/b.sound_speed_m_s;
    assert(max(arrival)-min(arrival)<1e-12);
    if depth==20, assert(max(abs(q.tx.delay_s(:)-b.tx.delay_s(:)))<1e-12); end
end
disp('Focus-depth inputs passed.');
end
