function curing_multifocus_compare_20261114()
% Compare single-pulse uncalibrated full fields on the existing physical grid.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'results','multifocus_2026-11-14');
names={'All64','Dual','Quad'}; foci={0,[-2 2],[-3 -1 1 3]};
rows=repmat(struct('variant','','dx_um',0,'focus_x_mm','','focus_pressure','', ...
    'focus_qp','','interval_min_pressure',NaN,'plane_line_max',0, ...
    'plane_line_max_x_mm',0,'target_z_sample_mm',0,'forward_peak',0, ...
    'forward_peak_x_mm',0,'forward_peak_y_mm',0,'forward_peak_z_mm',0, ...
    'final_over_peak',0,'binary_sha256',''),1,6);
traces=cell(2,3); t=0;
for gi=1:2
    dx=[65 52]; spacing=dx(gi);
    for j=1:3
        if j==1, file=fullfile(out,sprintf('baseline_dx%d_field.mat',spacing));
        else, file=fullfile(out,sprintf('%s_dx%d_field.mat',lower(names{j}),spacing)); end
        s=load(file,'p_amp','qp','x_m','y_m','z_m','runtime_metadata','final_over_peak');
        x=double(s.x_m(:))*1e3; y=double(s.y_m(:))*1e3; z=double(s.z_m(:))*1e3;
        [~,iy]=min(abs(y)); [~,iz]=min(abs(z-20));
        pressure=double(s.p_amp(:,iy,iz)); q=double(s.qp(:,iy,iz));
        traces{gi,j}=struct('x',x,'p',pressure,'q',q);
        targets=foci{j}; vals=zeros(size(targets)); qvals=vals;
        for k=1:numel(targets)
            [~,ix]=min(abs(x-targets(k))); vals(k)=pressure(ix); qvals(k)=q(ix);
        end
        mask=x>=min(targets) & x<=max(targets);
        if isscalar(targets), trough=NaN; else, trough=min(pressure(mask)); end
        [peak,index]=max(pressure); t=t+1;
        rows(t).variant=names{j}; rows(t).dx_um=spacing;
        rows(t).focus_x_mm=mat2str(targets); rows(t).focus_pressure=mat2str(vals,6);
        rows(t).focus_qp=mat2str(qvals,6); rows(t).interval_min_pressure=trough;
        rows(t).plane_line_max=peak; rows(t).plane_line_max_x_mm=x(index);
        rows(t).target_z_sample_mm=z(iz);
        forward=find(z>=2); block=s.p_amp(:,:,forward); [maximum,index]=max(block,[],'all','linear');
        [px,py,pz]=ind2sub(size(block),index);
        rows(t).forward_peak=double(maximum); rows(t).forward_peak_x_mm=x(px);
        rows(t).forward_peak_y_mm=y(py); rows(t).forward_peak_z_mm=z(forward(pz));
        clear block
        rows(t).final_over_peak=s.final_over_peak;
        rows(t).binary_sha256=s.runtime_metadata.binary_sha256;
        if gi==2
            writetable(table(x,pressure,q,'VariableNames',{'x_mm','peak_pressure_assumed_pa','qp_assumed_pa2_s'}), ...
                fullfile(out,[lower(names{j}) '_target_profile_dx52.csv']));
            figure(101); set(gcf,'Visible','off','Color','w','Position',[100 100 1500 600]); subplot(1,3,j); imagesc(x,z,squeeze(s.p_amp(:,iy,:))');
            axis image; set(gca,'YDir','normal'); clim([0 3]); colorbar; hold on;
            plot(targets,20*ones(size(targets)),'w+','LineWidth',1.5); xlabel('x (mm)'); ylabel('z (mm)'); title(names{j});
            figure(102); set(gcf,'Visible','off','Color','w','Position',[100 100 1500 600]); subplot(1,3,j); imagesc(x,y,squeeze(s.p_amp(:,:,iz))');
            axis image; set(gca,'YDir','normal'); clim([0 3]); colorbar; hold on;
            plot(targets,zeros(size(targets)),'w+','LineWidth',1.5); xlabel('x (mm)'); ylabel('y (mm)'); title(names{j});
        end
        clear s
    end
end
writetable(struct2table(rows),fullfile(out,'comparison.csv'));
figure(101); sgtitle('Single-pulse max |p|, assumed Pa, y=0, 52 um'); exportgraphics(gcf,fullfile(out,'compare_xz.png'),'Resolution',150); close(gcf);
figure(102); sgtitle('Single-pulse max |p|, assumed Pa, z=20 mm, 52 um'); exportgraphics(gcf,fullfile(out,'compare_xy.png'),'Resolution',150); close(gcf);
figure('Visible','off','Color','w'); hold on;
for j=1:3, plot(traces{2,j}.x,traces{2,j}.p,'DisplayName',names{j}); end
xlim([-7.8 7.8]); grid on; legend; xlabel('x (mm)'); ylabel('max |p| (assumed Pa)'); title('Target-plane profile, y=0, 52 um');
exportgraphics(gcf,fullfile(out,'compare_profile.png'),'Resolution',150); close(gcf);
% 260 um is a common grid spacing for 65 and 52 um meshes.
for j=1:3
    a=traces{1,j}; b=traces{2,j}; [common,ia,ib]=intersect(round(a.x,6),round(b.x,6));
    assert(~isempty(common)); relative=norm(a.p(ia)-b.p(ib))/norm(b.p(ib));
    fprintf('%s common target line pressure L2 relative difference %.6g\n',names{j},relative);
end
end
