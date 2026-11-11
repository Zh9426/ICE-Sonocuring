function result=curing_source_interpolation_diagnostic_20261111()
% Diagnostic only: interpolation does not establish physical convergence.
root=fileparts(mfilename('fullpath'));
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_shallow');
files={'all64_dx32p5_narrow_field.mat','all64_dx26_narrow_field.mat'};
labels={'dx32p5';'dx26'}; native=zeros(2,1); interpPeak=native; px=native; py=native;
for i=1:2
    a=load(fullfile(base,files{i}),'qp','x_m','y_m','z_m');
    [~,iz]=min(abs(a.z_m)); assert(abs(a.z_m(iz))<1e-12);
    x=a.x_m(:); y=a.y_m(:); q=double(a.qp(:,:,iz)); native(i)=max(q(:));
    % Evaluate only the central physical overlap on a 6.5 um lattice.
    xi=(-780:780)'*6.5e-6; yi=(-380:380)'*6.5e-6;
    assert(min(xi)>=min(x) && max(xi)<=max(x) && min(yi)>=min(y) && max(yi)<=max(y));
    [X,Y]=ndgrid(xi,yi); qi=interpn(x,y,q,X,Y,'spline');
    [interpPeak(i),k]=max(qi(:)); [ix,iy]=ind2sub(size(qi),k);
    px(i)=xi(ix)*1e3; py(i)=yi(iy)*1e3;
end
result=table(labels,native,interpPeak,px,py,'VariableNames', ...
    {'grid','native_qp_peak','spline_qp_peak','spline_x_mm','spline_y_mm'});
out=fullfile(base,'all64_source_interpolation_diagnostic_20261111.csv');
assert(~isfile(out),'iceind:NoOverwrite','Diagnostic output exists.');
writetable(result,out); disp(result);
fprintf('Native peak change %.4f%%; spline peak change %.4f%%. Diagnostic only.\n', ...
    100*(native(2)/native(1)-1),100*(interpPeak(2)/interpPeak(1)-1));
end
