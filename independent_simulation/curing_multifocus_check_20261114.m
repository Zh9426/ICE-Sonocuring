function curing_multifocus_check_20261114()
root=fileparts(mfilename('fullpath')); addpath(root);
base=load(fullfile(root,'results','curing_export_2026-11-10','ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat'));
b=iceind.compile_kwave(base); pos=b.geometry.positions_m; c=b.sound_speed_m_s;
[~,order]=sort(pos(:,1)); target=[0 0 0.020];
d=vecnorm(pos-target,2,2); common=(max(d)-d)/c;
assert(max(abs(common(:)-b.tx.delay_s(:)))<1e-12,'Single-focus baseline differs.');
for name={'dual','quad'}
    s=load(fullfile(root,'results','multifocus_2026-11-14',[name{1} '_simulation_input.mat']));
    q=iceind.compile_kwave(s); f=s.multifocus_assumption.focus_x_mm;
    assert(isscalar(q.tx) && all(q.tx.apod==1));
    arrivals=zeros(64,1);
    for k=1:numel(f)
        idx=order((k-1)*64/numel(f)+1:k*64/numel(f));
        dist=vecnorm(pos(idx,:)-[f(k)*1e-3 0 .020],2,2);
        arrivals(idx)=q.tx.delay_s(idx)'+dist/c;
    end
    assert(max(arrivals)-min(arrivals)<1e-12,'Common time reference mismatch.');
    fprintf('%s arrival spread %.6g ns\n',name{1},(max(arrivals)-min(arrivals))*1e9);
end
fprintf('Single-focus equivalence and per-group arrivals passed.\n');
end
