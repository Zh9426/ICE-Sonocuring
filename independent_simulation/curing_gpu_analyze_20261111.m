function result=curing_gpu_analyze_20261111(rawPath,outputDir,pressureLimits)
%CURING_GPU_ANALYZE_20261111 Native-grid slices, profiles and target metrics.
% Assumed pressure/Qp only. No actual acoustic power, heat or cure inference.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old)); addpath(root);
if nargin<3, pressureLimits=[]; end
assert(isfile(rawPath),'iceind:GPUAnalysis','Missing field MAT.');
assert(~isfolder(outputDir),'iceind:NoOverwrite','Analysis folder exists; inspect it.'); mkdir(outputDir);
s=load(rawPath,'p_amp','qp','x_m','y_m','z_m','target_m','meta','runtime_metadata', ...
    'dt_s','Nt','elapsed','final_over_peak');
x=s.x_m(:)'; y=s.y_m(:)'; z=s.z_m(:)'; n=[numel(x) numel(y) numel(z)];
assert(isequal(size(s.p_amp),n) && isequal(size(s.qp),n) && ...
    all(isfinite(s.p_amp),'all') && all(isfinite(s.qp),'all') && ...
    all(s.p_amp(:)>=0) && all(s.qp(:)>=0),'iceind:GPUAnalysis','Invalid field values/dimensions.');
dx=mean(diff(x)); m=iceind.curing_field_metrics(s.p_amp,x,y,z,s.target_m,dx);
assert(~m.target_peak_is_zero,'iceind:GPUAnalysis','Target box peak is zero.');
[~,ix]=min(abs(x-m.target_peak_xyz_m(1))); [~,iy]=min(abs(y-m.target_peak_xyz_m(2)));
[~,iz]=min(abs(z-m.target_peak_xyz_m(3)));
[~,it]=min(abs(x-s.target_m(1))); [~,jt]=min(abs(y-s.target_m(2))); [~,kt]=min(abs(z-s.target_m(3)));
qp_peak_location=double(s.qp(ix,iy,iz)); qp_target=double(s.qp(it,jt,kt));
[outsideAll,outsideXYZ,outsideQp]=outside_target_all(s.p_amp,s.qp,x,y,z,s.target_m);
result=struct('metrics',m,'qp_at_target_peak_pa2_s',qp_peak_location, ...
    'qp_at_target_point_pa2_s',qp_target,'target_peak_sample_xyz_m',[x(ix) y(iy) z(iz)], ...
    'outside_all_z_ge_zero_peak_assumed_pa',outsideAll, ...
    'outside_all_z_ge_zero_peak_xyz_m',outsideXYZ,'qp_at_outside_peak_pa2_s',outsideQp, ...
    'pressure_units','assumed Pa','qp_units','assumed Pa^2 s', ...
    'input_mat',rawPath,'dt_s',s.dt_s,'Nt',s.Nt,'elapsed_s',s.elapsed, ...
    'final_over_global_peak',s.final_over_peak,'case',s.runtime_metadata.case, ...
    'target_width_definition','Amplitude -6 dB crossings on each full native-grid axis through target-box peak; NaN if clipped.', ...
    'notes',['Uncalibrated equal per-element source; Qp is pressure squared integral, not measured energy or heat. ' ...
    'Outside-target peak is reported for z>=0 and separately for z>=2 mm. ' ...
    'A target-box peak on its ROI boundary is not established as a distinct focus.']);
iceind.curing_field_write_json(fullfile(outputDir,'metrics.json'),result);
T=table(string(s.runtime_metadata.case.variant),s.runtime_metadata.case.dx_m*1e6, ...
    m.target_peak_xyz_m(1)*1e3,m.target_peak_xyz_m(2)*1e3,m.target_peak_xyz_m(3)*1e3, ...
    m.target_peak_error_to_target_m*1e3,m.target_peak_on_box_boundary, ...
    m.target_peak_widths_m(1)*1e3,m.target_peak_widths_m(2)*1e3,m.target_peak_widths_m(3)*1e3, ...
    m.target_peak_width_clipped(1),m.target_peak_width_clipped(2),m.target_peak_width_clipped(3), ...
    m.target_point_over_target_peak,m.outside_target_box_peak_pa_assumed, ...
    m.outside_target_peak_xyz_m(1)*1e3,m.outside_target_peak_xyz_m(2)*1e3, ...
    m.outside_target_peak_xyz_m(3)*1e3,outsideAll,outsideXYZ(1)*1e3, ...
    outsideXYZ(2)*1e3,outsideXYZ(3)*1e3,outsideQp,m.shallow_0_2mm_over_forward_peak, ...
    m.shallow_2_5mm_over_forward_peak,m.target_box_peak_pa_assumed,qp_peak_location,qp_target, ...
    'VariableNames',{'variant','dx_um','target_peak_x_mm','target_peak_y_mm','target_peak_z_mm', ...
    'target_peak_error_mm','target_peak_on_roi_boundary','target_width_x_mm','target_width_y_mm','target_width_z_mm', ...
    'target_width_x_clipped','target_width_y_clipped','target_width_z_clipped','target_point_over_target_peak', ...
    'outside_forward_peak_assumed_pa','outside_forward_x_mm','outside_forward_y_mm','outside_forward_z_mm', ...
    'outside_all_peak_assumed_pa','outside_all_x_mm','outside_all_y_mm','outside_all_z_mm','qp_at_outside_peak_assumed_pa2_s', ...
    'shallow_0_2_over_forward_peak','shallow_2_5_over_forward_peak', ...
    'target_peak_assumed_pa','qp_at_target_peak_assumed_pa2_s','qp_at_target_assumed_pa2_s'});
writetable(T,fullfile(outputDir,'metrics.csv'));
writetable(axial_peak_table(s.p_amp,s.qp,x,y,z),fullfile(outputDir,'axial_regions.csv'));
fig=figure('Visible','off','Color','w');
imagesc(x*1e3,z*1e3,squeeze(s.p_amp(:,iy,:))'); axis image; set(gca,'YDir','normal');
xlabel('x (mm)'); ylabel('z (mm)'); title(sprintf('%s: target-box peak x-z at y=%.3f mm',s.runtime_metadata.case.tag,y(iy)*1e3),'Interpreter','none');
if ~isempty(pressureLimits), clim(pressureLimits); end; cb=colorbar; cb.Label.String='Peak pressure (assumed Pa)';
hold on; plot(x(ix)*1e3,z(iz)*1e3,'wx','MarkerSize',9,'LineWidth',1.5);
exportgraphics(fig,fullfile(outputDir,'pressure_xz.png'),'Resolution',150); close(fig);
fig=figure('Visible','off','Color','w');
imagesc(x*1e3,y*1e3,squeeze(s.p_amp(:,:,iz))'); axis image; set(gca,'YDir','normal');
xlabel('x (mm)'); ylabel('y (mm)'); title(sprintf('%s: target-box peak x-y at z=%.3f mm',s.runtime_metadata.case.tag,z(iz)*1e3),'Interpreter','none');
if ~isempty(pressureLimits), clim(pressureLimits); end; cb=colorbar; cb.Label.String='Peak pressure (assumed Pa)';
hold on; plot(x(ix)*1e3,y(iy)*1e3,'wx','MarkerSize',9,'LineWidth',1.5);
exportgraphics(fig,fullfile(outputDir,'pressure_xy.png'),'Resolution',150); close(fig);
[~,ifwd]=min(abs(x-m.forward_peak_xyz_m(1))); [~,jfwd]=min(abs(y-m.forward_peak_xyz_m(2)));
[~,kfwd]=min(abs(z-m.forward_peak_xyz_m(3)));
fig=figure('Visible','off','Color','w');
imagesc(x*1e3,y*1e3,squeeze(s.p_amp(:,:,kfwd))'); axis image; set(gca,'YDir','normal');
xlabel('x (mm)'); ylabel('y (mm)'); title(sprintf('%s: forward peak plane z=%.3f mm',s.runtime_metadata.case.tag,z(kfwd)*1e3),'Interpreter','none');
if ~isempty(pressureLimits), clim(pressureLimits); end; cb=colorbar; cb.Label.String='Peak pressure (assumed Pa)';
hold on; plot(x(ifwd)*1e3,y(jfwd)*1e3,'wx','MarkerSize',9,'LineWidth',1.5);
exportgraphics(fig,fullfile(outputDir,'pressure_xy_forward_peak.png'),'Resolution',150); close(fig);
axesData={x,y,z}; pressure={double(s.p_amp(:,iy,iz)),double(s.p_amp(ix,:,iz)),double(squeeze(s.p_amp(ix,iy,:)))};
qdata={double(s.qp(:,iy,iz)),double(s.qp(ix,:,iz)),double(squeeze(s.qp(ix,iy,:)))};
labels={'x','y','z'}; fig=figure('Visible','off','Color','w','Position',[50 50 1100 900]);
for j=1:3
    coord=axesData{j}(:)*1e3; pressure_j=pressure{j}(:); qp_j=qdata{j}(:);
    subplot(3,2,2*j-1); plot(coord,pressure_j); xlabel([labels{j} ' (mm)']); ylabel('Peak pressure (assumed Pa)'); grid on;
    subplot(3,2,2*j); plot(coord,qp_j); xlabel([labels{j} ' (mm)']); ylabel('Qp (assumed Pa^2 s)'); grid on;
    writetable(table(coord,pressure_j,qp_j,'VariableNames',{'coordinate_mm','peak_assumed_pa','qp_assumed_pa2_s'}), ...
        fullfile(outputDir,['profile_' labels{j} '.csv']));
end
sgtitle(sprintf('%s: profiles through target-box peak',s.runtime_metadata.case.tag),'Interpreter','none');
exportgraphics(fig,fullfile(outputDir,'profiles_xyz.png'),'Resolution',150); close(fig);
end
function [peak,xyz,qpAtPeak]=outside_target_all(p,qp,x,y,z,target)
% Include the shallow z>=0 domain; exclude the fixed analysis target box.
outsideXY=abs(x(:)-target(1))>2e-3+1e-12 | abs(y(:)'-target(2))>2e-3+1e-12;
peak=-Inf; xyz=[NaN NaN NaN]; qpAtPeak=NaN;
for k=1:numel(z)
    if z(k)<0, continue; end
    plane=p(:,:,k);
    if abs(z(k)-target(3))<=4e-3+1e-12, plane(~outsideXY)=-Inf; end
    [v,idx]=max(plane(:));
    if double(v)>peak
        [i,j]=ind2sub(size(plane),idx); peak=double(v); xyz=[x(i) y(j) z(k)];
        qpAtPeak=double(qp(i,j,k));
    end
end
if ~isfinite(peak), peak=NaN; end
if ~isfinite(peak) || peak==0, xyz=[NaN NaN NaN]; qpAtPeak=NaN; end
end
function T=axial_peak_table(p,qp,x,y,z)
% Regions are full lateral planes, not restricted to the target box.
names={'shallow_0_2mm';'shallow_2_5mm';'prefocal_5_16mm'; ...
    'target_depth_16_24mm';'postfocal_ge_24mm'};
limits=[0 2;2 5;5 16;16 24;24 Inf]*1e-3;
peak=nan(5,1); xp=peak; yp=peak; zp=peak; q=peak;
qmax=peak; qx=peak; qy=peak; qz=peak;
for j=1:5
    iz=find(z>=limits(j,1) & z<limits(j,2));
    if isempty(iz), continue; end
    sub=p(:,:,iz); [v,k]=max(sub(:)); [i,ii,kk]=ind2sub(size(sub),k); kk=iz(kk);
    peak(j)=double(v);
    if v>0
        xp(j)=x(i)*1e3; yp(j)=y(ii)*1e3; zp(j)=z(kk)*1e3;
        q(j)=double(qp(i,ii,kk));
    end
    qsub=qp(:,:,iz); [vq,kq]=max(qsub(:)); [iq,jq,kq]=ind2sub(size(qsub),kq); kq=iz(kq);
    qmax(j)=double(vq);
    if vq>0, qx(j)=x(iq)*1e3; qy(j)=y(jq)*1e3; qz(j)=z(kq)*1e3; end
end
T=table(names,peak,xp,yp,zp,q,qmax,qx,qy,qz,'VariableNames', ...
    {'region','peak_assumed_pa','x_mm','y_mm','z_mm','qp_at_peak_assumed_pa2_s', ...
    'qp_peak_assumed_pa2_s','qp_peak_x_mm','qp_peak_y_mm','qp_peak_z_mm'});
end
