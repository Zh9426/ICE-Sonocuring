function rows=curing_bli_edge_boundary_20261110()
%CURING_BLI_EDGE_BOUNDARY_20261110 Check outermost 64-array source support.
% This is a source-grid boundary test, not a wave propagation or lens model.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
out=fullfile(root,'results','curing_field_2026-11-10','bli_edge_boundary');
assert(~isfolder(out),'iceind:NoOverwrite','Output already exists.'); mkdir(out);
domain=[15.6 10.4 31.2]*1e-3; z0=-domain(3)/2+.52e-3;
rows=struct('dx_um',{},'x_mm',{},'boundary_x',{},'boundary_y',{}, ...
    'boundary_z_near',{},'boundary_z_far',{},'nonzero_points',{});
for dx=[65e-6 52e-6]
    n=round(domain/dx); g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
    for xpos=[-4.095e-3 4.095e-3]
        a=kWaveArray('BLITolerance',.05,'UpsamplingRate',10);
        a.addRectElement([xpos 0 z0],.11e-3,2.02e-3,[0 0 0]);
        w=a.getElementGridWeights(g,1);
        rows(end+1)=struct('dx_um',dx*1e6,'x_mm',xpos*1e3, ...
            'boundary_x',any(w(1,:,:),'all')||any(w(end,:,:),'all'), ...
            'boundary_y',any(w(:,1,:),'all')||any(w(:,end,:),'all'), ...
            'boundary_z_near',any(w(:,:,1),'all'), ...
            'boundary_z_far',any(w(:,:,end),'all'),'nonzero_points',nnz(w)); %#ok<AGROW>
    end
end
writetable(struct2table(rows),fullfile(out,'edge_boundary.csv'));
disp(struct2table(rows));
end
