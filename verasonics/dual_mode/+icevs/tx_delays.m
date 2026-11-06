function [delays_wls, FocalPt] = tx_delays(Trans, focus_wls, steer_rad, apod, origin_wls)
%TX_DELAYS Type-2 plane-wave delays; historical type-0 focused/plane geometry.
% Positive focus is converging, zero is a plane wave, and negative focus
% is a virtual source behind the array (for forward steering angles).
% The minimum active-element delay is zero; disabled-element delays are zero.
% Divide returned delays by Trans.frequency*1e6 to obtain delay in seconds.
%
% Matrix focused beams use focus_delays with explicit 3D target coordinates.
% Linear type-0 paths reject elevation steering and nonzero origin y/z.
% No HVMux or nonplanar geometry is supported. All physical parameters and
% medium homogeneity remain assumed unless independently calibrated.
% Reference: D00163 Rev. K, section 4.3.2, p.25; appendix A171-A173;
% VantageNXT-2.3.2-p2/Utilities/computeTXDelays.m, type-0 branch.
% Hardware delay quantization and maximum delay checks belong to the caller.

if nargin < 5
    origin_wls = [0 0 0];
end
required = {'numelements','frequency','type','units','ElementPos'};
if ~isstruct(Trans) || ~isscalar(Trans) || ~all(isfield(Trans,required))
    error('icevs:Delays','Trans must contain numelements, frequency, type, units, and ElementPos.');
end
if ~finite_scalar(Trans.type) || ~ismember(Trans.type,[0 2]) || isfield(Trans,'HVMux')
    error('icevs:Delays','Only planar linear/matrix arrays without HVMux are supported.');
end
if ~(ischar(Trans.units) || (isstring(Trans.units) && isscalar(Trans.units))) || ...
        ~strcmp(Trans.units,'wavelengths')
    error('icevs:Delays','Trans.units must be wavelengths.');
end
if ~finite_scalar(Trans.numelements) || Trans.numelements < 1 || ...
        Trans.numelements ~= fix(Trans.numelements) || ...
        ~finite_scalar(Trans.frequency) || Trans.frequency <= 0
    error('icevs:Delays','Trans must have a positive integer element count and positive finite frequency.');
end
n = double(Trans.numelements);
positions = Trans.ElementPos;
if ~finite_real(positions) || ~ismatrix(positions) || size(positions,1) ~= n || ...
        size(positions,2) < 3 || any(positions(:,3)~=0) || ...
        (Trans.type==0 && any(positions(:,2)~=0))
    error('icevs:Delays','Trans.ElementPos must contain finite type-0 positions with y=z=0.');
end
if ~finite_scalar(focus_wls)
    error('icevs:Delays','focus_wls must be a finite real scalar.');
end
if ~finite_real(steer_rad) || ~isvector(steer_rad) || numel(steer_rad) ~= 2 || ...
        (Trans.type==0 && steer_rad(2) ~= 0)
    error('icevs:Delays','steer_rad must be finite [azimuth 0]; elevation steering is unsupported.');
end
if ~finite_real(origin_wls) || ~isvector(origin_wls) || numel(origin_wls) ~= 3 || ...
        origin_wls(3)~=0 || (Trans.type==0 && origin_wls(2)~=0)
    error('icevs:Delays','origin_wls must be finite [x 0 0] for this linear-array implementation.');
end
if ~(isnumeric(apod) || islogical(apod)) || ~isreal(apod) || ~isvector(apod) || ...
        numel(apod) ~= n || any(~isfinite(apod(:))) || any(apod(:) < 0 | apod(:) > 1) || ~any(apod(:) > 0)
    error('icevs:Delays','apod must have N entries in [0,1], with at least one active element.');
end

x = double(positions(:,1))';
if Trans.type==2
    if focus_wls~=0
        error('icevs:Delays','Matrix focuses use focus_delays with an explicit 3D target.');
    end
    distance=(x-origin_wls(1))*sin(steer_rad(1)) + ...
        (positions(:,2)'-origin_wls(2))*sin(steer_rad(2));
    active=apod(:)'>0; delays_wls=zeros(1,n);
    delays_wls(active)=distance(active)-min(distance(active));
    FocalPt=[0 0 0]; return
end
azimuth = double(steer_rad(1));
originX = double(origin_wls(1));
FocalPt = [0 0 0];
if focus_wls == 0
    distance = (x-originX) * sin(azimuth);
else
    FocalPt = [originX + double(focus_wls)*sin(azimuth), 0, double(focus_wls)*cos(azimuth)];
    distance = hypot(x-FocalPt(1),FocalPt(3));
end
if any(~isfinite(distance)) || any(~isfinite(FocalPt))
    error('icevs:Delays','Computed geometry must remain finite.');
end
active = reshape(apod ~= 0,1,[]);
delays_wls = zeros(1,n);
if FocalPt(3) > 0
    delays_wls(active) = max(distance(active)) - distance(active);
else
    delays_wls(active) = distance(active) - min(distance(active));
end
end

function yes = finite_real(value)
yes = isnumeric(value) && isreal(value) && all(isfinite(value(:)));
end

function yes = finite_scalar(value)
yes = finite_real(value) && isscalar(value);
end
