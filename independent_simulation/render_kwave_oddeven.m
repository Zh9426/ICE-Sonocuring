function render_kwave_oddeven(file)
%RENDER_KWAVE_ODDEVEN Inspectable pressure sections and 3D peak-field isosurface.
s=load(file,'p_peak_pa','x_m','y_m','z_m','data','t_s','report');
x=s.x_m*1e3; y=s.y_m*1e3; z=s.z_m*1e3; p=s.p_peak_pa;
target=s.report.source.target_m*1e3; peak=s.report.metrics.forward_peak_xyz_m*1e3;
[~,iy]=min(abs(y-target(2))); [~,ix]=min(abs(x-target(1))); [~,iz]=min(abs(z-target(3)));
ref=s.report.metrics.forward_peak_pa_assumed;
fig=figure('Visible','off','Color','w','Position',[50 50 1450 850]);
cleanup=onCleanup(@()close(fig)); tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
nexttile; show(x,z,squeeze(p(:,iy,:))',ref); xlabel('x (mm)'); ylabel('z (mm)');
title('XZ: peak pressure (dB)'); hold on; plot(target(1),target(3),'w+','MarkerSize',10,'LineWidth',2); plot(peak(1),peak(3),'ro');
nexttile; show(y,z,squeeze(p(ix,:,:))',ref); xlabel('y (mm)'); ylabel('z (mm)');
title('YZ: peak pressure (dB)'); hold on; plot(target(2),target(3),'w+','MarkerSize',10,'LineWidth',2);
nexttile; show(x,y,p(:,:,iz)',ref); xlabel('x (mm)'); ylabel('y (mm)');
title(sprintf('XY at z = %.3f mm',z(iz))); hold on; plot(target(1),target(2),'w+','MarkerSize',10,'LineWidth',2);
nexttile; forward=find(z>=2); stride=2;
xs=x(1:stride:end); ys=y(1:stride:end); zs=z(forward(1):stride:end);
v=permute(p(1:stride:end,1:stride:end,forward(1):stride:end),[2 1 3]);
surface=isosurface(xs,ys,zs,v,ref*.5);
if ~isempty(surface.vertices)
    patch(surface,'FaceColor',[.2 .65 .85],'EdgeColor','none','FaceAlpha',.65);
end
hold on; plot3(target(1),target(2),target(3),'r+','MarkerSize',12,'LineWidth',2);
plot3(peak(1),peak(2),peak(3),'ko','MarkerFaceColor','k');
axis tight; daspect([1 1 1]); view(35,25); camlight; lighting gouraud; grid on;
xlabel('x (mm)'); ylabel('y (mm)'); zlabel('z (mm)'); title('3D half-peak surface; display decimated 2x');
nexttile; plot(z,squeeze(p(ix,iy,:)),'LineWidth',1.2); xline(target(3),'r--');
xlabel('z (mm)'); ylabel('max |p| (Pa, assumed)'); title('Target-axis pressure'); grid on; xlim([2 max(z)]);
nexttile; plot(s.t_s*1e6,s.data.p'); xlabel('Time (us)'); ylabel('p (Pa, assumed)');
title('Four sensor pressure histories'); grid on;
sgtitle(sprintf('Even 32 / 64 | 6 MHz | dx %.0f um | peak error %.3f mm | UNCALIBRATED', ...
    s.report.dx_m*1e6,s.report.metrics.forward_peak_error_m*1e3));
exportgraphics(fig,strrep(file,'.mat','.png'),'Resolution',140);
end
function show(x,y,p,reference)
imagesc(x,y,20*log10(max(double(p)/reference,1e-3))); axis image; axis xy;
clim([-40 0]); colorbar;
end
