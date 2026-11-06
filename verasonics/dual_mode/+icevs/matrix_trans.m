function Trans = matrix_trans(p,c)
%MATRIX_TRANS Type-2 rectangular array. Logical ordering is x-fast, not wiring.
% D00163 Rev.K section 13.1 pp107-110. Dimensions remain uncalibrated.
if ~isfield(p,'shape') || ~isnumeric(p.shape) || ~isreal(p.shape) || ...
        numel(p.shape)~=2 || any(~isfinite(p.shape)) || any(p.shape<2) || ...
        any(p.shape~=fix(p.shape)) || prod(p.shape)~=p.num_elements
    error('icevs:Probe','shape=[Nx Ny] must match the rectangular element count.');
end
if ~isnumeric(p.pitch_mm) || ~isreal(p.pitch_mm) || numel(p.pitch_mm)~=2 || ...
        any(~isfinite(p.pitch_mm)) || any(p.pitch_mm<=0) || ...
        ~isfield(p,'height_mm') || ~isnumeric(p.height_mm) || ~isreal(p.height_mm) || ...
        ~isscalar(p.height_mm) || ~isfinite(p.height_mm) || p.height_mm<=0 || p.height_mm>p.pitch_mm(2)
    error('icevs:Probe','Matrix pitch requires [dx dy], and height must fit dy.');
end
% Reuse scalar electrical/unit validation; no P9 lookup or phantom hardware.
base=rmfield(p,'type'); base.pitch_mm=p.pitch_mm(1);
base.elevation_aperture_mm=p.height_mm; base.elevation_focus_mm=1;
base.positions_mm=[];
Trans=icevs.make_trans(base,c);
Trans=rmfield(Trans,{'elevationApertureMm','elevationFocusMm'});
Trans.type=2;
if isempty(p.positions_mm)
    [ix,iy]=ndgrid(1:p.shape(1),1:p.shape(2));
    xyz=[(ix(:)-(p.shape(1)+1)/2)*p.pitch_mm(1), ...
        (iy(:)-(p.shape(2)+1)/2)*p.pitch_mm(2),zeros(p.num_elements,1)];
else
    xyz=p.positions_mm;
end
if ~isnumeric(xyz) || ~isreal(xyz) || ~isequal(size(xyz),[p.num_elements 3]) || ...
        any(~isfinite(xyz),'all') || any(xyz(:,3)~=0) || ...
        numel(unique(xyz(:,1)))~=p.shape(1) || numel(unique(xyz(:,2)))~=p.shape(2) || ...
        size(unique(xyz,'rows'),1)~=p.num_elements
    error('icevs:Probe','positions_mm must describe every unique point of a planar rectangular grid.');
end
if min(diff(sort(unique(xyz(:,1)))))<p.width_mm || min(diff(sort(unique(xyz(:,2)))))<p.height_mm
    error('icevs:Probe','Explicit element centers overlap the specified rectangular widths/heights.');
end
Trans.ElementPos=[xyz*(p.frequency_mhz/(c/1000)),zeros(p.num_elements,2)];
Trans.spacingMm=min(p.pitch_mm); Trans.spacing=Trans.spacingMm*p.frequency_mhz/(c/1000);
% VSX accepts one axially symmetric 101-sample sensitivity for type 2.
% This cos(theta) approximation is assumed, not rectangular 2D directivity.
Trans.ElementSens=abs(cos(linspace(-pi/2,pi/2,101)));
end
