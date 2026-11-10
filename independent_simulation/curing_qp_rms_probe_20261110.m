function results=curing_qp_rms_probe_20261110()
%CURING_QP_RMS_PROBE Validate RMS-derived Qp and full-mask grid indexing.
% Small, assumed point source: not a four-driver or calibrated field.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
out=fullfile(root,'results','curing_field_2026-11-10','qp_rms_probe');
assert(~isfolder(out),'iceind:NoOverwrite','Probe output already exists.'); mkdir(out);
n=[24 20 16]; dx=100e-6; g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
g.setTime(320,.2*dx/1540);
medium=struct('sound_speed',1540,'density',1000);
source=struct(); source.p_mask=false(n); source.p_mask(7,8,4)=true;
source.p=single(sin(2*pi*6e6*g.t_array).*(g.t_array<20/6e6));
sensor=struct(); sensor.mask=true(n);
sensor.record={'p','p_rms','p_max_all','p_min_all'};
results=struct('record_start',{},'recorded_samples',{},'qp_relative_l2',{}, ...
    'qp_max_absolute_pa2_s',{},'qp_max_relative_above_floor',{}, ...
    'pmax_max_absolute',{},'pmin_max_absolute',{},'window_trace_max_absolute',{},'runtime_s',{});
referenceTraces=[];
for start=[1 37]
    sensor.record_start_index=start; tic;
    data=kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false, ...
        'PMLSize',8,'PlotSim',false,'DataCast','single'); elapsed=toc;
    traces=double(data.p);
    assert(size(traces,2)==g.Nt-start+1,'iceind:QpRms','Incorrect recorded sample count.');
    if start==1
        referenceTraces=traces; windowError=0;
    else
        windowError=max(abs(traces-referenceTraces(:,start:end)),[],'all');
    end
    direct=g.dt*sum(traces.^2,2);
    rmsQ=double(data.p_rms(:)).^2*size(traces,2)*g.dt;
    err=abs(direct-rmsQ); floorMask=direct>1e-6*max(direct);
    maxErr=max(abs(reshape(max(traces,[],2),n)-double(data.p_max_all)),[],'all');
    minErr=max(abs(reshape(min(traces,[],2),n)-double(data.p_min_all)),[],'all');
    results(end+1)=struct('record_start',start,'recorded_samples',size(traces,2), ...
        'qp_relative_l2',norm(err)/norm(direct),'qp_max_absolute_pa2_s',max(err), ...
        'qp_max_relative_above_floor',max(err(floorMask)./direct(floorMask)), ...
        'pmax_max_absolute',maxErr,'pmin_max_absolute',minErr, ...
        'window_trace_max_absolute',windowError,'runtime_s',elapsed); %#ok<AGROW>
    time_s=g.t_array(start:end); dt_s=g.dt; %#ok<NASGU>
    save(fullfile(out,sprintf('fullmask_start%d.mat',start)),'data','time_s','dt_s','n','-v7.3');
end
% Reproduce the toolbox single-precision recurrence with a long zero tail.
sig=[single(source.p(:));zeros(6000,1,'single')]; rmsValue=single(0);
for k=1:numel(sig)
    rmsValue=sqrt((rmsValue.^2*single(k-1)+sig(k).^2)/single(k));
end
qDirect=g.dt*sum(double(sig).^2); qRms=double(rmsValue)^2*numel(sig)*g.dt;
longTailRelativeError=abs(qDirect-qRms)/qDirect;
writetable(struct2table(results),fullfile(out,'fullmask_comparison.csv'));
save(fullfile(out,'long_tail.mat'),'sig','qDirect','qRms','longTailRelativeError');
disp(struct2table(results)); fprintf('long-tail relative error: %.6g\n',longTailRelativeError);
assert(all([results.qp_max_relative_above_floor]<1e-3) && ...
    all([results.pmax_max_absolute]<1e-6) && all([results.pmin_max_absolute]<1e-6) && ...
    all([results.window_trace_max_absolute]<1e-6) && ...
    longTailRelativeError<1e-3,'iceind:QpRms','RMS/indexing diagnostic exceeded tolerance.');
end
