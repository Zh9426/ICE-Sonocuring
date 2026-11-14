function curing_focus_depth_compare_20261114(dx)
% Compare saved single-pulse fields at a common grid, including the original All64.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'results','focus_depth_2026-11-14');
depths=[16 18 20 22]; rows=[]; hashes=strings(4,1);
mapFigure=figure('Visible','off','Color','w','Position',[50 50 1600 500]);
profileFigure=figure('Visible','off','Color','w','Position',[50 50 900 600]); hold on;
for j=1:numel(depths)
    depth=depths(j);
    if depth==20
        file=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full',sprintf('all64_dx%d_field.mat',dx));
    else
        file=fullfile(out,sprintf('focus%d_dx%d_field.mat',depth,dx));
    end
    s=load(file,'p_amp','qp','x_m','y_m','z_m','final_over_peak','dt_s','Nt','runtime_metadata','target_m');
    assert(norm(double(s.target_m(:))-[0;0;depth*1e-3])<1e-12,'Field target does not match its group.');
    x=double(s.x_m(:))*1e3; y=double(s.y_m(:))*1e3; z=double(s.z_m(:))*1e3;
    [~,ix]=min(abs(x)); [~,iy]=min(abs(y)); [~,iz]=min(abs(z-depth));
    line=double(squeeze(s.p_amp(ix,iy,:)));
    keep=find(z>=2); block=s.p_amp(:,:,keep);
    [peak,idx]=max(block,[],'all','linear'); [px,py,pz]=ind2sub(size(block),idx);
    qblock=s.qp(:,:,keep); [qpeak,qidx]=max(qblock,[],'all','linear');
    [qx,qy,qz]=ind2sub(size(qblock),qidx);
    rows=[rows; depth dx z(iz) line(iz) double(peak) x(px) y(py) z(keep(pz)) ...
        z(keep(pz))-depth double(s.qp(ix,iy,iz)) double(qpeak) x(qx) y(qy) z(keep(qz)) ...
        s.final_over_peak s.dt_s s.Nt]; %#ok<AGROW>
    hashes(j)=string(s.runtime_metadata.binary_sha256);
    figure(profileFigure); plot(z,line,'DisplayName',sprintf('%d mm',depth));
    writetable(table(z,line,'VariableNames',{'z_mm','peak_pressure_assumed_pa'}), ...
        fullfile(out,sprintf('focus%d_axial_dx%d.csv',depth,dx)));
    figure(mapFigure); subplot(1,4,j); imagesc(x,z,squeeze(s.p_amp(:,iy,:))');
    axis image; set(gca,'YDir','normal'); clim([0 3.5]); colorbar; hold on;
    plot(0,depth,'w+','LineWidth',1.5); xlabel('x (mm)'); ylabel('z (mm)'); title(sprintf('Target %d mm',depth));
    clear s block qblock
end
t=array2table(rows,'VariableNames',{'target_mm','grid_um','sample_z_mm','target_pressure_assumed_pa', ...
    'forward_peak_assumed_pa','peak_x_mm','peak_y_mm','peak_z_mm','peak_offset_mm', ...
    'target_qp_assumed_pa2_s','forward_peak_qp_assumed_pa2_s','qp_peak_x_mm','qp_peak_y_mm', ...
    'qp_peak_z_mm','final_over_global_peak','dt_s','Nt'});
t.binary_sha256=hashes;
writetable(t,fullfile(out,sprintf('comparison_dx%d.csv',dx)));
figure(mapFigure); sgtitle(sprintf('max |p|, assumed Pa, y=0, %d um',dx));
exportgraphics(gcf,fullfile(out,sprintf('focus_depth_xz_dx%d.png',dx)),'Resolution',150); close(gcf);
figure(profileFigure); grid on; legend('Location','best'); xlim([0 31.2]);
xlabel('Depth z (mm)'); ylabel('max |p| (assumed Pa)'); title(sprintf('All64 on-axis pressure, %d um',dx));
exportgraphics(gcf,fullfile(out,sprintf('focus_depth_axial_dx%d.png',dx)),'Resolution',150); close(gcf);
disp(t);
end
