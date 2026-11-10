function [w,wx,wy]=curing_field_weights(x_vec,y_vec,dx,positions_m,width_m,height_m)
%CURING_FIELD_WEIGHTS Exact area-overlap rasterization of finite rectangles.
% w is [Nx*Ny x Ne] with rows ordered by (x,y) as produced by reshape of a
% logical Nx-by-Ny plane. wx/wy are the separable 1-D overlap fractions.
% The column sums must reproduce width*height exactly (no clipping).
nx=numel(x_vec); ny=numel(y_vec); ne=size(positions_m,1);
assert(size(positions_m,2)>=1 && all(isfinite(positions_m(:,1))) && ...
    isscalar(dx) && dx>0 && isscalar(width_m) && width_m>0 && ...
    isscalar(height_m) && height_m>0,'iceind:CuringField', ...
    'Finite positive geometry required.');
wx=zeros(nx,ne); wy=zeros(ny,ne);
for j=1:ne
    wx(:,j)=max(0,min(x_vec+dx/2,positions_m(j,1)+width_m/2)- ...
        max(x_vec-dx/2,positions_m(j,1)-width_m/2))/dx;
    wy(:,j)=max(0,min(y_vec+dx/2,height_m/2)- ...
        max(y_vec-dx/2,-height_m/2))/dx;
end
w=zeros(nx*ny,ne,'single');
for j=1:ne
    w(:,j)=single(reshape(wx(:,j)*wy(:,j)',[],1));
end
end
