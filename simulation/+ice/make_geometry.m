function geom = make_geometry(array)
%MAKE_GEOMETRY Centred rectangular linear/matrix aperture in the x-y plane.
%   All lengths are metres. x varies fastest in the flattened element list.
%   Linear arrays require size(2) == 1; their element height is independent of
%   y pitch. See simulation/array_geometry/README.md for coordinate details.
required = {'type','size','pitch_m','element_width_m','element_height_m'};
if ~isstruct(array) || ~isscalar(array) || ~all(isfield(array,required))
    error('ice:Geometry','Array requires type, size, pitch_m, and element dimensions.');
end
type = enum_text(array.type, {'linear','matrix'});
sz = array.size;
if ~isnumeric(sz) || ~isreal(sz) || numel(sz) ~= 2 || ...
        any(~isfinite(sz(:))) || any(sz(:)<1) || any(sz(:)~=fix(sz(:)))
    error('ice:Geometry','Array size must contain two positive integer counts.');
end
sz = double(reshape(sz,1,2));
if strcmp(type,'linear') && sz(2) ~= 1
    error('ice:Geometry','A linear array requires size = [Nx 1].');
end
pitch = array.pitch_m;
if ~isnumeric(pitch) || ~isreal(pitch) || numel(pitch) ~= 2 || ...
        any(~isfinite(pitch(:))) || any(pitch(:)<=0)
    error('ice:Geometry','pitch_m must contain two positive finite spacings.');
end
pitch = double(reshape(pitch,1,2));
w = array.element_width_m;
h = array.element_height_m;
if ~positive_scalar(w) || ~positive_scalar(h)
    error('ice:Geometry','Element width and height must be positive finite scalars.');
end
if w > pitch(1) || (sz(2)>1 && h>pitch(2))
    error('ice:Geometry','Element dimensions must not exceed pitch in populated dimensions.');
end
[ix,iy] = ndgrid(1:sz(1),1:sz(2));
x = (double(ix(:))-(sz(1)+1)/2)*pitch(1);
y = (double(iy(:))-(sz(2)+1)/2)*pitch(2);
n = prod(sz);
geom = struct('positions_m',[x,y,zeros(n,1)], ...
    'width_m',repmat(double(w),n,1),'height_m',repmat(double(h),n,1), ...
    'grid_indices',[ix(:),iy(:)],'shape',sz,'normal',[0 0 1],'type',type);
end

function tf = positive_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value>0;
end

function value = enum_text(value, choices)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || ~isrow(value) || ~any(strcmp(value,choices))
    error('ice:Geometry','Array type must be linear or matrix.');
end
end
