function curing_compare_sparse_20261113()
% Compare native-grid fields; peaks are uncalibrated and are not energy.
root=fileparts(mfilename('fullpath')); addpath(root);
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
dest=fullfile(root,'results','curing_sparse_2026-11-12','comparison_20261113');
assert(~isfolder(dest),'iceind:NoOverwrite','Comparison folder already exists.'); mkdir(dest);
variants={'All64','Center32','Odd32','Even32'}; grids=[65 52];
rows=cell(8,1); regions=cell(8,1); target=cell(8,1); k=0;
f1=figure('Visible','off','Color','w','Position',[50 50 1500 600]);
f2=figure('Visible','off','Color','w','Position',[50 50 1500 350]);
for g=1:2
    for i=1:4
        k=k+1; tag=sprintf('%s_dx%d',lower(variants{i}),grids(g));
        adir=fullfile(base,['analysis_' tag]);
        rows{k}=readtable(fullfile(adir,'metrics.csv'));
        regions{k}=readtable(fullfile(adir,'axial_regions.csv'));
        regions{k}.variant=repmat(string(variants{i}),height(regions{k}),1);
        regions{k}.dx_um=repmat(grids(g),height(regions{k}),1);
        s=load(fullfile(base,[tag '_field.mat']),'p_amp','qp','x_m','y_m','z_m');
        x=s.x_m(:); y=s.y_m(:); z=s.z_m(:);
        [~,ix]=min(abs(x)); [~,iy]=min(abs(y)); [~,iz]=min(abs(z-.020)); [~,iz0]=min(abs(z));
        a=double(s.qp(:,:,iz0)); [q0,j]=max(a(:)); [qx,qy]=ind2sub(size(a),j);
        target{k}=table(string(variants{i}),grids(g),x(ix)*1e3,y(iy)*1e3,z(iz)*1e3, ...
            double(s.p_amp(ix,iy,iz)),double(s.qp(ix,iy,iz)),q0,x(qx)*1e3,y(qy)*1e3, ...
            'VariableNames',{'variant','dx_um','sample_x_mm','sample_y_mm','sample_z_mm', ...
            'pressure_assumed_pa','qp_assumed_pa2_s','source_plane_qp_max_assumed_pa2_s', ...
            'source_plane_max_x_mm','source_plane_max_y_mm'});
        if grids(g)==52
            figure(f1); subplot(1,4,i); imagesc(x*1e3,z*1e3,squeeze(s.p_amp(:,iy,:))');
            axis image; set(gca,'YDir','normal'); clim([0 3.3]); colorbar; hold on;
            plot(0,20,'w+','MarkerSize',9,'LineWidth',1.3); xlabel('x (mm)'); ylabel('z (mm)');
            title(variants{i},'Interpreter','none');
            figure(f2); subplot(1,4,i); imagesc(x*1e3,y*1e3,squeeze(s.p_amp(:,:,iz))');
            axis image; set(gca,'YDir','normal'); clim([0 3.3]); colorbar; hold on;
            plot(0,0,'w+','MarkerSize',9,'LineWidth',1.3); xlabel('x (mm)'); ylabel('y (mm)');
            title(sprintf('%s z=%.3f mm',variants{i},z(iz)*1e3),'Interpreter','none');
        end
    end
end
figure(f1); sgtitle('Peak pressure x-z at y=0, assumed Pa; + is target');
exportgraphics(f1,fullfile(dest,'comparison_xz_dx52.png'),'Resolution',150); close(f1);
figure(f2); sgtitle('Peak pressure x-y at target depth, assumed Pa; + is target');
exportgraphics(f2,fullfile(dest,'comparison_xy_target_dx52.png'),'Resolution',150); close(f2);
writetable(vertcat(rows{:}),fullfile(dest,'metrics.csv'));
writetable(vertcat(regions{:}),fullfile(dest,'axial_regions.csv'));
writetable(vertcat(target{:}),fullfile(dest,'target_source_plane.csv'));
for i=3:4
    curing_bli_compare_grids_20261110(variants{i},base);
end
end
