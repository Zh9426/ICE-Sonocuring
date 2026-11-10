function s=curing_field_representation(axis_vec,frac,dx,width_m)
%CURING_FIELD_REPRESENTATION Summarize a 1-D rasterized finite rectangle.
% axis_vec are voxel centres (m), frac are overlap fractions in [0,1] such
% that sum(frac)*dx == width_m. Returns centroid/second-moment diagnostics
% and the discrete-vs-continuous aperture spectrum used for the source audit.
axis_vec=axis_vec(:); frac=double(frac(:));
assert(isequal(size(axis_vec),size(frac)) && isscalar(dx) && dx>0 && ...
    isscalar(width_m) && width_m>0 && all(isfinite(frac)) && ...
    all(frac>=-1e-12) && all(frac<=1+1e-12),'iceind:CuringField','Invalid 1-D weights.');
frac=max(0,min(1,frac));
area=sum(frac)*dx;
centroid=sum(frac.*axis_vec)/sum(frac);
m2=sum(frac.*(axis_vec-centroid).^2)/sum(frac);
exact_m2=width_m^2/12;
% Normalized continuous rectangle transform: mean of exp(-i2pi f x) over the
% rectangle equals sinc(width*f) with sinc(x)=sin(pi x)/(pi x).
f=linspace(0,1/(2*dx),4097);
discrete=zeros(size(f));
for k=1:numel(f)
    discrete(k)=abs(sum(frac.*exp(-2i*pi*f(k)*axis_vec))/sum(frac));
end
cont=abs(sinc_local(width_m*f));
df=f(2)-f(1); denom=sqrt(sum(cont.^2)*df);
s=struct('covered_length_m',area,'area_relative_error',area/(width_m)-1, ...
    'centroid_m',centroid,'second_moment_m2',m2, ...
    'exact_second_moment_m2',exact_m2, ...
    'effective_width_m',sqrt(12*m2), ...
    'effective_width_relative_error',sqrt(12*m2)/width_m-1, ...
    'spectrum_l2_relative_error',sqrt(sum((discrete-cont).^2)*df)/denom, ...
    'spectrum_max_abs_error',max(abs(discrete-cont)), ...
    'crossover_fraction_of_nyquist',find(discrete<0.5,1,'first')/numel(f), ...
    'cells_per_width',width_m/dx);
end
function y=sinc_local(x)
y=ones(size(x)); nz=x~=0; y(nz)=sin(pi*x(nz))./(pi*x(nz));
end
