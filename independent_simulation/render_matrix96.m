function render_matrix96(file)
%RENDER_MATRIX96 Full-volume data retained; display-only mesh is downsampled.
d=load(file,'peak_abs','x','y','z','report','m','c');
[folder,tag]=fileparts(file);
fig=figure('Visible','off','Color','w','Position',[30 30 1400 850]);cl=onCleanup(@()close(fig));
tiledlayout(2,2,'Padding','compact');
ax=nexttile;hold(ax,'on');
ix=1:2:numel(d.x);iy=1:2:numel(d.y);iz=find(d.z>=d.c.roi_z_m(1) & d.z<=d.c.roi_z_m(2));iz=iz(1:2:end);
[X,Y,Z]=meshgrid(d.x(ix)*1e3,d.y(iy)*1e3,d.z(iz)*1e3);
V=permute(d.peak_abs(ix,iy,iz),[2 1 3]);
colors=[.1 .45 .9;.1 .75 .6;.95 .4 .1];levels=[-12 -6 -3];
for k=1:3
    fv=isosurface(X,Y,Z,V,d.report.roi_peak_pa_assumed*10^(levels(k)/20));
    if ~isempty(fv.vertices),patch(ax,fv,'FaceColor',colors(k,:),'EdgeColor','none','FaceAlpha',.18+.12*k);end
end
scatter3(ax,d.m.positions_m(:,1)*1e3,d.m.positions_m(:,2)*1e3,zeros(96,1),15,double(d.m.active),'filled');
plot3(ax,d.c.focus_m(1)*1e3,d.c.focus_m(2)*1e3,d.c.focus_m(3)*1e3,'kp','MarkerSize',12);
axis(ax,'equal');grid(ax,'on');view(ax,35,25);xlabel('x mm');ylabel('y mm');zlabel('z mm');
title({'ROI peak-pressure surfaces: -12/-6/-3 dB','Clipped ROI; not an instantaneous wavefront'});
[~,a]=min(abs(d.x));[~,b]=min(abs(d.y));[~,q]=min(abs(d.z-d.c.focus_m(3)));
nexttile;imagesc(d.x*1e3,d.z*1e3,squeeze(d.peak_abs(:,b,:))');axis image;set(gca,'YDir','normal');colorbar;xlabel('x mm');ylabel('z mm');title('XZ peak |p| (Pa, assumed)');
nexttile;imagesc(d.y*1e3,d.z*1e3,squeeze(d.peak_abs(a,:,:))');axis image;set(gca,'YDir','normal');colorbar;xlabel('y mm');ylabel('z mm');title('YZ peak |p| (Pa, assumed)');
nexttile;imagesc(d.x*1e3,d.y*1e3,d.peak_abs(:,:,q)');axis image;set(gca,'YDir','normal');colorbar;xlabel('x mm');ylabel('y mm');title(sprintf('XY at z=%.3f mm (Pa, assumed)',d.z(q)*1e3));
sgtitle(sprintf('96 elements / 12x8 / %s / uncalibrated assumed geometry',d.m.partition));
savefig(fig,fullfile(folder,[tag '.fig']));exportgraphics(fig,fullfile(folder,[tag '.png']),'Resolution',130);
end
