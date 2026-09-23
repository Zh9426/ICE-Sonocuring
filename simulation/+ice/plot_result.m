function fig = plot_result(r, filename)
%PLOT_RESULT Orthogonal peak-pressure maps, threshold mask and aperture.
% Colors use the COMMON pressure reference. White contour is own-peak -6 dB;
% magenta contour is target. Black threshold mask is a separate definition.
g=r.grid;shape=g.shape;field=reshape(r.exposure.pressure_peak_pa,shape);
ref=r.reference.pressure_peak_pa;
if ref<=0,error('ice:ZeroReference','Plotting needs a positive pressure reference.');end
db=max(r.cfg.output.db_floor,20*log10(max(field/ref,realmin)));
own=max(field(:))*10^(-6/20);
[~,iy]=min(abs(g.y_m-r.cfg.target.center_m(2)));
[~,iz]=min(abs(g.z_m-r.cfg.target.center_m(3)));
target=reshape(r.target_mask,shape);above=reshape(r.metrics.threshold_mask,shape);
fig=figure('Visible',r.cfg.output.visible,'Color','w','Position',[100 100 1200 850]);
tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
ax=nexttile;imagesc(ax,g.x_m*1e3,g.z_m*1e3,squeeze(db(:,iy,:)).');
axis(ax,'xy');axis(ax,'image');hold(ax,'on');
contour_if(ax,g.x_m*1e3,g.z_m*1e3,squeeze(field(:,iy,:)).',own,'w');
contour_if(ax,g.x_m*1e3,g.z_m*1e3,double(squeeze(target(:,iy,:))).',.5,'m');
clim(ax,[r.cfg.output.db_floor,max(0,max(db(:)))]);colorbar(ax);xlabel(ax,'x (mm)');ylabel(ax,'z (mm)');
title(ax,'Peak envelope / shared-focused reference (dB)');
ax=nexttile;imagesc(ax,g.x_m*1e3,g.y_m*1e3,db(:,:,iz).');axis(ax,'xy');axis(ax,'image');hold(ax,'on');
contour_if(ax,g.x_m*1e3,g.y_m*1e3,field(:,:,iz).',own,'w');
contour_if(ax,g.x_m*1e3,g.y_m*1e3,double(target(:,:,iz)).',.5,'m');
clim(ax,[r.cfg.output.db_floor,max(0,max(db(:)))]);colorbar(ax);xlabel(ax,'x (mm)');ylabel(ax,'y (mm)');
title(ax,sprintf('Transverse slice z = %.2f mm',g.z_m(iz)*1e3));
ax=nexttile;imagesc(ax,g.x_m*1e3,g.z_m*1e3,double(squeeze(above(:,iy,:))).');
axis(ax,'xy');axis(ax,'image');hold(ax,'on');colormap(ax,[.95 .96 .98;.15 .25 .35]);clim(ax,[0 1]);
contour_if(ax,g.x_m*1e3,g.z_m*1e3,double(squeeze(target(:,iy,:))).',.5,'m');
xlabel(ax,'x (mm)');ylabel(ax,'z (mm)');
title(ax,sprintf('Threshold proxy: C=%.3f, L=%.3f, CV=%.3f', ...
    r.metrics.target_coverage,r.metrics.off_target_exposure,r.metrics.target_uniformity_cv));
ax=nexttile;hold(ax,'on');gg=r.geometry;
for j=1:size(gg.positions_m,1)
    if r.partition.curing_mask(j)&&r.partition.imaging_mask(j),color=[.3 .55 .8];
    elseif r.partition.curing_mask(j),color=[.85 .4 .15];else,color=[.5 .65 .55];end
    rectangle(ax,'Position',1e3*[gg.positions_m(j,1)-gg.width_m(j)/2, ...
        gg.positions_m(j,2)-gg.height_m(j)/2,gg.width_m(j),gg.height_m(j)], ...
        'FaceColor',color,'EdgeColor','w');
end
axis(ax,'equal');grid(ax,'on');xlabel(ax,'x (mm)');ylabel(ax,'y (mm)');
title(ax,sprintf('Aperture: %d curing; blue shared, orange curing, green imaging',r.drive.active_elements));
sgtitle(sprintf('%s | %s | %s | %s | %.2f MHz\nWhite: own peak -6 dB; magenta: target; no cure prediction', ...
    upper(r.cfg.provenance.kind),r.cfg.array.type,r.cfg.excitation.mode,r.cfg.architecture.type,r.cfg.acoustics.frequency_hz/1e6), ...
    'Interpreter','none');
if nargin>1&&~isempty(filename),exportgraphics(fig,filename,'Resolution',160);end
end

function contour_if(ax,x,y,v,level,color)
if min(v(:))<level&&max(v(:))>level
    contour(ax,x,y,v,[level level],color,'LineWidth',1.3);
end
end
