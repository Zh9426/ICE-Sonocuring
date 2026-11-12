function curing_compare_four_20261112()
% Native-grid four-variant comparison, equal assumed source per element.
% The shallow raw-grid maxima remain grid-sensitive; no safety claim.
root=fileparts(mfilename('fullpath')); addpath(root);
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
dest=fullfile(base,'four_variant_comparison_20261112');
assert(~isfolder(dest),'iceind:NoOverwrite','Comparison folder exists.'); mkdir(dest);
variants={'All64','Center48','Center32','Center16'}; grids=[65 52];
rows=cell(8,1); regions=cell(8,1); audit=cell(8,1); k=0;
fig1=figure('Visible','off','Color','w','Position',[50 50 1400 700]);
fig2=figure('Visible','off','Color','w','Position',[50 50 1400 700]);
for g=1:numel(grids)
    for i=1:numel(variants)
        k=k+1; tag=sprintf('%s_dx%d',lower(variants{i}),grids(g));
        folder=fullfile(base,['analysis_' tag]);
        rows{k}=readtable(fullfile(folder,'metrics.csv'));
        regions{k}=readtable(fullfile(folder,'axial_regions.csv'));
        regions{k}.variant=repmat(string(variants{i}),height(regions{k}),1);
        regions{k}.dx_um=repmat(grids(g),height(regions{k}),1);
        s=load(fullfile(base,[tag '_field.mat']),'p_amp','qp','x_m','y_m','z_m','meta','runtime_metadata');
        x=s.x_m(:); y=s.y_m(:); z=s.z_m(:);
        [~,ix]=min(abs(x)); [~,iy]=min(abs(y)); [~,iz]=min(abs(z-0.020)); [~,iz0]=min(abs(z));
        q0=double(s.qp(:,:,iz0)); [qmax,j]=max(q0(:)); [qx,qy]=ind2sub(size(q0),j);
        audit{k}=table(string(variants{i}),grids(g),x(ix)*1e3,y(iy)*1e3,z(iz)*1e3, ...
            double(s.p_amp(ix,iy,iz)),double(s.qp(ix,iy,iz)),qmax,x(qx)*1e3,y(qy)*1e3, ...
            'VariableNames',{'variant','dx_um','target_sample_x_mm','target_sample_y_mm', ...
            'target_sample_z_mm','target_sample_pressure_assumed_pa','target_sample_qp_assumed_pa2_s', ...
            'source_plane_qp_max_assumed_pa2_s','source_plane_max_x_mm','source_plane_max_y_mm'});
        if grids(g)==52
            figure(fig1); subplot(1,4,i); imagesc(x*1e3,z*1e3,squeeze(s.p_amp(:,iy,:))');
            axis image; set(gca,'YDir','normal'); clim([0 3]); colorbar; hold on;
            plot(0,20,'w+','MarkerSize',10,'LineWidth',1.4); xlabel('x (mm)'); ylabel('z (mm)');
            title(variants{i},'Interpreter','none');
            figure(fig2); subplot(1,4,i); imagesc(x*1e3,y*1e3,squeeze(s.p_amp(:,:,iz))');
            axis image; set(gca,'YDir','normal'); clim([0 3]); colorbar; hold on;
            plot(0,0,'w+','MarkerSize',10,'LineWidth',1.4); xlabel('x (mm)'); ylabel('y (mm)');
            title(sprintf('%s, z=%.3f mm',variants{i},z(iz)*1e3),'Interpreter','none');
        end
end
end
figure(fig1); sgtitle('Peak pressure, x-z at y=0; assumed Pa; + is target');
exportgraphics(fig1,fullfile(dest,'four_xz_dx52.png'),'Resolution',150); close(fig1);
figure(fig2); sgtitle('Peak pressure, x-y near target; assumed Pa; + is target');
exportgraphics(fig2,fullfile(dest,'four_xy_target_dx52.png'),'Resolution',150); close(fig2);
writetable(vertcat(rows{:}),fullfile(dest,'metrics_four_variants.csv'));
writetable(vertcat(regions{:}),fullfile(dest,'axial_regions_four_variants.csv'));
writetable(vertcat(audit{:}),fullfile(dest,'target_and_source_plane.csv'));
for i=2:3
    curing_bli_compare_grids_20261110(variants{i},base);
end
end
