function partition = partition_elements(geom, architecture)
%PARTITION_ELEMENTS Assign numerical imaging and curing aperture masks.
%   Generated masks use round(fraction*N) curing elements, clamped to [1,N-1].
%   Geometric ties are resolved by original element index. This can break
%   reflection symmetry when an exact count cuts through a tied pair/ring.
%   Random sparse uses a local stream and never modifies global RNG state.
if ~isstruct(geom) || ~isscalar(geom) || ~isfield(geom,'positions_m') || ...
        ~isnumeric(geom.positions_m) || ~isreal(geom.positions_m) || ...
        size(geom.positions_m,2)~=3 || isempty(geom.positions_m) || ...
        any(~isfinite(geom.positions_m(:)))
    error('ice:Partition','Geometry must contain nonempty finite N-by-3 positions.');
end
n = size(geom.positions_m,1);
if ~isstruct(architecture) || ~isscalar(architecture) || ~isfield(architecture,'type')
    error('ice:Partition','Architecture must specify shared or partitioned type.');
end
type = enum_text(architecture.type, {'shared','partitioned','dual_array'});
if strcmp(type,'shared')
    partition = struct('imaging_mask',true(n,1),'curing_mask',true(n,1));
    return
end
if strcmp(type,'dual_array')
    if ~all(isfield(geom,{'imaging_mask','curing_mask'})) || ...
            ~isequal(size(geom.imaging_mask),[n 1]) || ...
            ~isequal(size(geom.curing_mask),[n 1]) || ...
            ~islogical(geom.imaging_mask) || ~islogical(geom.curing_mask) || ...
            ~any(geom.imaging_mask) || ~any(geom.curing_mask) || ...
            any(geom.imaging_mask & geom.curing_mask) || ...
            ~all(geom.imaging_mask | geom.curing_mask)
        error('ice:Partition','Dual array geometry needs nonempty disjoint imaging/curing masks.');
    end
    partition=struct('imaging_mask',geom.imaging_mask,'curing_mask',geom.curing_mask);
    return
end
if n<2
    error('ice:Partition','Partitioned architecture requires at least two elements.');
end
if ~all(isfield(architecture,{'pattern','curing_fraction'}))
    error('ice:Partition','Partitioned architecture requires pattern and curing_fraction.');
end
pattern = enum_text(architecture.pattern, ...
    {'central_curing','peripheral_curing','checkerboard','random_sparse','custom', ...
    'left_curing','right_curing','lower_curing','upper_curing'});
f = architecture.curing_fraction;
if ~isnumeric(f) || ~isreal(f) || ~isscalar(f) || ~isfinite(f) || f<=0 || f>=1
    error('ice:Partition','curing_fraction must be strictly between zero and one.');
end
count = max(1,min(n-1,round(double(f)*n)));
curing = false(n,1);
xy = double(geom.positions_m(:,1:2));
xy = xy-mean(xy,1);
r2 = sum(xy.^2,2);
index = (1:n)';
switch pattern
    case 'central_curing'
        [~,order] = sortrows([r2,index],[1 2]);
        curing(order(1:count)) = true;
    case 'peripheral_curing'
        [~,order] = sortrows([-r2,index],[1 2]);
        curing(order(1:count)) = true;
    case 'checkerboard'
        if ~isfield(geom,'grid_indices') || ~isnumeric(geom.grid_indices) || ...
                ~isequal(size(geom.grid_indices),[n,2]) || ...
                any(~isfinite(geom.grid_indices(:))) || ...
                any(geom.grid_indices(:)~=fix(geom.grid_indices(:)))
            error('ice:Partition','Checkerboard requires integer N-by-2 grid_indices.');
        end
        parity = mod(sum(geom.grid_indices,2),2);
        [~,order] = sortrows([parity,r2,index],[1 2 3]);
        curing(order(1:count)) = true;
    case 'left_curing'
        [~,order] = sortrows([xy,index],[1 2 3]);
        curing(order(1:count)) = true;
    case 'right_curing'
        [~,order] = sortrows([xy,index],[-1 2 3]);
        curing(order(1:count)) = true;
    case 'lower_curing'
        [~,order] = sortrows([xy,index],[2 1 3]);
        curing(order(1:count)) = true;
    case 'upper_curing'
        [~,order] = sortrows([xy,index],[-2 1 3]);
        curing(order(1:count)) = true;
    case 'random_sparse'
        if ~isfield(architecture,'seed')
            error('ice:Partition','Random sparse requires an explicit integer seed.');
        end
        seed = architecture.seed;
        if ~isnumeric(seed) || ~isreal(seed) || ~isscalar(seed) || ...
                ~isfinite(seed) || seed<0 || seed>2^32-1 || seed~=fix(seed)
            error('ice:Partition','seed must be an integer between 0 and 2^32-1.');
        end
        stream = RandStream('mt19937ar','Seed',double(seed));
        curing(randperm(stream,n,count)) = true;
    case 'custom'
        if ~isfield(architecture,'custom_curing_mask')
            error('ice:Partition','Custom pattern requires custom_curing_mask.');
        end
        value = architecture.custom_curing_mask;
        if ~(islogical(value) || isnumeric(value)) || ~isreal(value) || ...
                ~isequal(size(value),[n 1]) || any(value(:)~=0 & value(:)~=1)
            error('ice:Partition','custom_curing_mask must be a binary N-by-1 vector.');
        end
        curing = logical(value);
        if ~any(curing) || all(curing)
            error('ice:Partition','Custom partition must leave both subarrays nonempty.');
        end
end
partition = struct('imaging_mask',~curing,'curing_mask',curing);
end

function value = enum_text(value, choices)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || ~isrow(value) || ~any(strcmp(value,choices))
    error('ice:Partition','Unsupported architecture type or partition pattern.');
end
end
