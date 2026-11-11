function result=curing_source_peak_diagnostic_20261111()
%CURING_SOURCE_PEAK_DIAGNOSTIC_20261111 Source-plane native vs common maxima.
% All values are single-pulse assumed Qp, not measured energy/temperature.
root=fileparts(mfilename('fullpath'));
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_shallow');
a=load(fullfile(base,'all64_dx32p5_narrow_field.mat'),'qp','x_m','y_m','z_m');
b=load(fullfile(base,'all64_dx26_narrow_field.mat'),'qp','x_m','y_m','z_m');
out=fullfile(base,'all64_source_peak_diagnostic_20261111.csv');
assert(~isfile(out),'iceind:NoOverwrite','Diagnostic output exists.');
xa=a.x_m(:); ya=a.y_m(:); xb=b.x_m(:); yb=b.y_m(:);
ia=1:4:numel(xa); ja=1:4:numel(ya); ib=1:5:numel(xb); jb=1:5:numel(yb);
assert(max(abs(xa(ia)-xb(ib)))<1e-12 && max(abs(ya(ja)-yb(jb)))<1e-12, ...
    'iceind:Shallow','Common 130 um coordinates differ.');
[~,za]=min(abs(a.z_m)); [~,zb]=min(abs(b.z_m));
assert(abs(a.z_m(za))<1e-12 && abs(b.z_m(zb))<1e-12);
nativeA=double(a.qp(:,:,za)); nativeB=double(b.qp(:,:,zb));
commonA=nativeA(ia,ja); commonB=nativeB(ib,jb);
[va,ka]=max(commonA(:)); [vb,kb]=max(commonB(:));
[ax,ay]=ind2sub(size(commonA),ka); [bx,by]=ind2sub(size(commonB),kb);
sameA=commonA(bx,by); sameB=commonB(bx,by);
[na,nai]=max(nativeA(:)); [nb,nbi]=max(nativeB(:));
[nax,nay]=ind2sub(size(nativeA),nai); [nbx,nby]=ind2sub(size(nativeB),nbi);
result=table(na,nb,100*(nb/na-1),va,vb,100*(vb/va-1), ...
    sameA,sameB,100*(sameB/sameA-1),xa(ia(bx))*1e3,ya(ja(by))*1e3, ...
    xa(nax)*1e3,ya(nay)*1e3,xb(nbx)*1e3,yb(nby)*1e3, ...
    'VariableNames',{'native_qp_32p5','native_qp_26','native_change_pct', ...
    'common_max_qp_32p5','common_max_qp_26','common_max_change_pct', ...
    'qp_32p5_at_fine_common_max','qp_26_at_fine_common_max','same_point_change_pct', ...
    'common_x_mm','common_y_mm','native32_x_mm','native32_y_mm','native26_x_mm','native26_y_mm'});
writetable(result,out);
fig=figure('Visible','off','Color','w','Position',[50 50 900 500]);
plot(xa(ia)*1e3,commonA(:,by)*1e6,'-o',xb(ib)*1e3,commonB(:,by)*1e6,'-x','LineWidth',1.2);
grid on; xlabel('x (mm)'); ylabel('Qp (10^{-6} assumed Pa^2 s)');
title(sprintf('z=0 common 130 um points at y=%.3f mm',ya(ja(by))*1e3));
legend('32.5 um','26 um','Location','best');
exportgraphics(fig,fullfile(base,'all64_source_common_line_20261111.png'),'Resolution',150); close(fig);
disp(result);
end
