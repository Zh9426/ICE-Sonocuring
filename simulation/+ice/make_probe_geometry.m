function geom = make_probe_geometry(probe)
%MAKE_PROBE_GEOMETRY Combine two independent, coplanar ICE subarrays.
% Each subarray has an existing array specification and offset_m [x y 0].
% The common +z normal and z=0 plane are required by solve_pressure.
if ~isstruct(probe) || ~isscalar(probe) || ~all(isfield(probe,{'kind','imaging','curing'})) || ...
        ~strcmp(char(string(probe.kind)),'dual_array')
    error('ice:ProbeGeometry','Probe requires kind=dual_array and imaging/curing subarrays.');
end
names = {'imaging','curing'};
groups = cell(1,2);
for j=1:2
    part = probe.(names{j});
    if ~isstruct(part) || ~isscalar(part) || ~all(isfield(part,{'array','offset_m'}))
        error('ice:ProbeGeometry','Each subarray requires array and offset_m.');
    end
    offset = part.offset_m;
    if ~isnumeric(offset) || ~isreal(offset) || ~isequal(size(offset),[1 3]) || ...
            any(~isfinite(offset)) || offset(3)~=0
        error('ice:ProbeGeometry','Subarray offset_m must be finite [x y 0] metres.');
    end
    try
        groups{j}=ice.make_geometry(part.array);
    catch cause
        error('ice:ProbeGeometry','Invalid %s subarray: %s',names{j},cause.message);
    end
    groups{j}.positions_m=groups{j}.positions_m+offset;
end
a=groups{1};b=groups{2};
for i=1:size(a.positions_m,1)
    x_overlap=abs(a.positions_m(i,1)-b.positions_m(:,1)) < (a.width_m(i)+b.width_m)/2;
    y_overlap=abs(a.positions_m(i,2)-b.positions_m(:,2)) < (a.height_m(i)+b.height_m)/2;
    if any(x_overlap & y_overlap)
        error('ice:ProbeGeometry','Independent subarray element faces must not overlap.');
    end
end
n1=size(a.positions_m,1);n2=size(b.positions_m,1);n=n1+n2;
geom=struct('positions_m',[a.positions_m;b.positions_m], ...
    'width_m',[a.width_m;b.width_m], 'height_m',[a.height_m;b.height_m], ...
    'grid_indices',[(1:n)',ones(n,1)], 'shape',[n 1], ...
    'normal',[0 0 1], 'type','dual_array', ...
    'subarray_id',[ones(n1,1);2*ones(n2,1)], ...
    'subarray_shape',{{a.shape,b.shape}}, ...
    'imaging_mask',[true(n1,1);false(n2,1)], ...
    'curing_mask',[false(n1,1);true(n2,1)]);
end
