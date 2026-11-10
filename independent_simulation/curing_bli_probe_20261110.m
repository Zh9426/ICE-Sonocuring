function rows=curing_bli_probe_20261110()
%CURING_BLI_PROBE_20261110 Single physical rectangle source-representation probe.
% No propagation, hardware, or calibrated acoustic output. The source centre,
% dimensions and 6 MHz are source-derived/assumed; BLI is non-local.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
out=fullfile(root,'results','curing_field_2026-11-10','bli_probe');
assert(~isfolder(out),'iceind:NoOverwrite','Probe output already exists.'); mkdir(out);
dxs=[65e-6 52e-6]; tolerances=[.05 .01]; ups=[10 20];
width=110e-6;height=2.02e-3; x0=-65e-6; c=1540; freq=6e6;
rows=struct('dx_um',{},'bli_tolerance',{},'upsampling',{},'signal_scale_sum',{}, ...
    'expected_area_over_dx2',{},'scale_error_fraction',{},'spectrum_error_75deg',{}, ...
    'boundary_nonzero',{},'nonzero_points',{},'runtime_s',{});
for dx=dxs
    n=round([12.48e-3 4.16e-3 4.16e-3]/dx);
    g=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
    for tol=tolerances
        for up=ups
            a=kWaveArray('BLITolerance',tol,'UpsamplingRate',up);
            a.addRectElement([x0 0 0],width,height,[0 0 0]);
            tic; weights=a.getElementGridWeights(g,1); elapsed=toc;
            total=sum(weights(:)); expected=width*height/dx^2;
            boundary=any(weights(1,:,:),'all')||any(weights(end,:,:),'all')|| ...
                any(weights(:,1,:),'all')||any(weights(:,end,:),'all')|| ...
                any(weights(:,:,1),'all')||any(weights(:,:,end),'all');
            fx=sind(75)*freq/c; fz=cosd(75)*freq/c;
            xz=squeeze(sum(weights,2));
            phasex=exp(-2i*pi*fx*g.x_vec(:)); phasez=exp(-2i*pi*fz*g.z_vec(:));
            numerical=abs((phasex.'*xz*phasez)/total);
            ideal=abs(sin(pi*width*fx)/(pi*width*fx));
            rows(end+1)=struct('dx_um',dx*1e6,'bli_tolerance',tol,'upsampling',up, ...
                'signal_scale_sum',total,'expected_area_over_dx2',expected, ...
                'scale_error_fraction',(total-expected)/expected, ...
                'spectrum_error_75deg',abs(numerical-ideal)/ideal, ...
                'boundary_nonzero',boundary,'nonzero_points',nnz(weights),'runtime_s',elapsed); %#ok<AGROW>
        end
    end
end
writetable(struct2table(rows),fullfile(out,'bli_source_representation.csv'));
save(fullfile(out,'bli_source_representation.mat'),'rows','dxs','tolerances','ups','width','height','x0','c','freq');
fprintf('BLI_PROBE rows=%d no propagation; output=%s\n',numel(rows),out); disp(struct2table(rows));
end
