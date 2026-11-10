function rows=curing_bli_propagation_probe_20261110()
%CURING_BLI_PROPAGATION_PROBE_20261110 Single-element 3-D propagation diagnostic.
% Not a four-driver field, not a calibrated transducer, and not cure or heat.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
out=fullfile(root,'results','curing_field_2026-11-10','bli_propagation_probe');
assert(~isfolder(out),'iceind:NoOverwrite','Probe output already exists.'); mkdir(out);
domain=[6.5 5.2 10.4]*1e-3; zoffset=.52e-3; width=.11e-3;height=2.02e-3;
% All requested points are multiples of 260 um and exactly on both grids.
points=[0 0 2.08;0 0 5.2;0 0 7.8;1.04 0 2.08;1.04 0 5.2]*1e-3;
rows=struct('dx_um',{},'point_index',{},'x_mm',{},'y_mm',{},'z_mm',{}, ...
    'peak_assumed_pa',{},'qp_assumed_pa2_s',{},'tail_over_peak',{},'runtime_s',{});
for dx=[65e-6 52e-6]
    n=round(domain/dx); g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
    g.makeTime(1540,.2,14e-6); z0=-domain(3)/2+zoffset;
    a=kWaveArray('BLITolerance',.05,'UpsamplingRate',10);
    a.addRectElement([-65e-6 0 z0],width,height,[0 0 0]);
    weights=a.getElementGridWeights(g,1);
    assert(~any(weights(1,:,:),'all') && ~any(weights(end,:,:),'all') && ...
        ~any(weights(:,1,:),'all') && ~any(weights(:,end,:),'all') && ...
        ~any(weights(:,:,1),'all') && ~any(weights(:,:,end),'all'), ...
        'iceind:BLIBoundary','BLI support touches probe-domain boundary.');
    source=struct(); source.p_mask=weights~=0;
    wave=single(sin(2*pi*6e6*g.t_array).*(g.t_array<20/6e6));
    source.p=single(weights(source.p_mask))*wave; source.p_mode='additive';
    sensor=struct();sensor.mask=false(n); actual=zeros(size(points));
    for j=1:size(points,1)
        [~,ix]=min(abs(g.x_vec-points(j,1)));[~,iy]=min(abs(g.y_vec-points(j,2)));
        [~,iz]=min(abs(g.z_vec-(z0+points(j,3))));
        actual(j,:)=[g.x_vec(ix),g.y_vec(iy),g.z_vec(iz)-z0];sensor.mask(ix,iy,iz)=true;
    end
    assert(max(abs(actual-points),[],'all')<1e-12 && nnz(sensor.mask)==size(points,1), ...
        'iceind:ProbeGeometry','Sensor coordinates must match exactly.');
    medium=struct('sound_speed',1540,'density',1000);tic;
    data=kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false, ...
        'PMLSize',round(1.04e-3/dx),'PlotSim',false,'DataCast','single'); elapsed=toc;
    [ix,iy,iz]=ind2sub(n,find(sensor.mask)); sensorXYZ=[g.x_vec(ix),g.y_vec(iy),g.z_vec(iz)-z0];
    traces=data; time_s=g.t_array; dt_s=g.dt;
    save(fullfile(out,sprintf('single_element_dx%02d_trace.mat',round(dx*1e6))), ...
        'traces','time_s','dt_s','sensorXYZ','wave','domain','z0','elapsed','dx','-v7.3');
    for j=1:size(points,1)
        [~,k]=min(vecnorm(sensorXYZ-points(j,:),2,2)); tr=double(traces(k,:));
        peak=max(abs(tr)); qp=sum(tr.^2)*g.dt; tail=max(abs(tr(end-19:end)))/max(peak,eps);
        rows(end+1)=struct('dx_um',dx*1e6,'point_index',j,'x_mm',points(j,1)*1e3, ...
            'y_mm',points(j,2)*1e3,'z_mm',points(j,3)*1e3, ...
            'peak_assumed_pa',peak,'qp_assumed_pa2_s',qp,'tail_over_peak',tail, ...
            'runtime_s',elapsed); %#ok<AGROW>
    end
end
writetable(struct2table(rows),fullfile(out,'point_trace_metrics.csv'));
fprintf('BLI_PROPAGATION_PROBE completed rows=%d output=%s\n',numel(rows),out);
disp(struct2table(rows));
end
