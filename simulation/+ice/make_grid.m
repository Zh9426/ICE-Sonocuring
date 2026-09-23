function grid = make_grid(spec)
%MAKE_GRID Uniform 3-D cell centers [m] -> M-by-3 points, shape, volume [m^3].
% All three axes need at least two centers; no implicit slice thickness.
names={'x_m','y_m','z_m'}; spacing=zeros(1,3);
for d=1:3
    a=spec.(names{d});
    if ~isnumeric(a)||~isreal(a)||~isvector(a)||numel(a)<2||any(~isfinite(a))
        error('ice:InvalidGrid','Each axis must have at least two finite real centers [m].');
    end
    a=a(:).'; delta=diff(a);
    if any(delta<=0)||max(abs(delta-delta(1)))>1e-9*delta(1)
        error('ice:InvalidGrid','Axes must be strictly increasing and uniformly spaced.');
    end
    grid.(names{d})=a; spacing(d)=delta(1);
end
if any(grid.z_m<=0),error('ice:InvalidGrid','Grid must be in the positive-z half-space.');end
[x,y,z]=ndgrid(grid.x_m,grid.y_m,grid.z_m);
grid.points_m=[x(:),y(:),z(:)];
grid.shape=[numel(grid.x_m),numel(grid.y_m),numel(grid.z_m)];
grid.spacing_m=spacing;grid.voxel_volume_m3=prod(spacing);
grid.coordinate_convention='uniform voxel centers; bounds extend half a cell';
end
