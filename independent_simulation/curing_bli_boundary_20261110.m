function rows=curing_bli_boundary_20261110()
% Single-element BLI support check at the planned physical-domain location.
% The test measures weights only; no 3D propagation or probe calibration.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
out=fullfile(root,'results','curing_field_2026-11-10','bli_boundary');
assert(~isfolder(out),'iceind:NoOverwrite','Output directory already exists.');mkdir(out);
domain=[15.6 10.4 31.2]*1e-3; sourceZ=-domain(3)/2+.52e-3;
rows=struct('dx_um',{},'tolerance',{},'upsampling',{},'source_offset_mm',{}, ...
    'boundary_x',{},'boundary_y',{},'boundary_z_near',{},'boundary_z_far',{}, ...
    'nonzero_points',{},'runtime_s',{});
for dx=[65e-6 52e-6]
    n=round(domain/dx); g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
    for tol=[.05 .01]
        a=kWaveArray('BLITolerance',tol,'UpsamplingRate',10);
        a.addRectElement([-65e-6 0 sourceZ],110e-6,2.02e-3,[0 0 0]);
        tic; w=a.getElementGridWeights(g,1); elapsed=toc;
        rows(end+1)=struct('dx_um',dx*1e6,'tolerance',tol,'upsampling',10, ...
            'source_offset_mm',.52,'boundary_x',any(w(1,:,:),'all')||any(w(end,:,:),'all'), ...
            'boundary_y',any(w(:,1,:),'all')||any(w(:,end,:),'all'), ...
            'boundary_z_near',any(w(:,:,1),'all'),'boundary_z_far',any(w(:,:,end),'all'), ...
            'nonzero_points',nnz(w),'runtime_s',elapsed); %#ok<AGROW>
    end
end
writetable(struct2table(rows),fullfile(out,'actual_domain_boundary.csv'));
save(fullfile(out,'actual_domain_boundary.mat'),'rows','domain','sourceZ');
fprintf('BLI_BOUNDARY rows=%d no propagation; output=%s\n',numel(rows),out);disp(struct2table(rows));
end
