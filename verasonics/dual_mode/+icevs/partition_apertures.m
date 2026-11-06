function [part,imageApod,exposureApod] = partition_apertures(cfg,Trans)
%PARTITION_APERTURES Physical +x order; independent of connector numbering.
% D00163 Rev.K section 13.1 p110: ConnectorES maps ElementPos row indices.
if ~ismember(Trans.type,[0 2])
    error('icevs:Partition','Requires a planar linear/matrix array.');
end
x=Trans.ElementPos(:,1); y=Trans.ElementPos(:,2); columns=sort(unique(x));
if mod(numel(columns),2)~=0
    error('icevs:Partition','Equal partitions require an even number of physical columns.');
end
[~,~,col]=unique(x); [~,~,row]=unique(y);
mid=NaN; % Interleaved apertures have no separating x boundary.
switch cfg.partition.layout
    case 'full64_imaging_selected_exposure'
        if Trans.type~=0 || Trans.numelements~=64 || numel(columns)~=64
            error('icevs:Partition','Shared aperture requires the original 64-element single-row array.');
        end
        if ~isfield(cfg.partition,'exposure_ranks')
            error('icevs:Partition','Provide exposure_ranks in ascending-physical-x numbering.');
        end
        ranks=cfg.partition.exposure_ranks;
        if ~isnumeric(ranks) || ~isreal(ranks) || ~isvector(ranks) || isempty(ranks) || ...
                any(~isfinite(ranks)) || any(ranks~=fix(ranks) | ranks<1 | ranks>64) || ...
                numel(unique(ranks))~=numel(ranks)
            error('icevs:Partition','exposure_ranks must be a nonempty unique integer subset of 1..64.');
        end
        imaging=true(size(x));
    case 'left_imaging_right_exposure'
        mid=mean(columns(numel(columns)/2+(0:1)));
        imaging=x<mid;
    case {'odd_imaging_even_exposure','even_imaging_odd_exposure'}
        if Trans.type~=0 || numel(columns)~=Trans.numelements
            error('icevs:Partition','Odd/even element partition requires a single-row linear array.');
        end
        imaging=mod(col,2)==1;
        if strcmp(cfg.partition.layout,'even_imaging_odd_exposure'), imaging=~imaging; end
    case 'full64_imaging_control'
        if Trans.type~=0 || ~strcmp(cfg.mode,'imaging_only')
            error('icevs:Partition','Full64 control is only available in linear imaging_only mode.');
        end
        imaging=true(size(x));
    otherwise
        error('icevs:Partition','Unknown physical partition layout.');
end
exposure=~imaging;
shared=strcmp(cfg.partition.layout,'full64_imaging_selected_exposure');
if shared, exposure=ismember(col,cfg.partition.exposure_ranks); end
% Control retains an unused exposure definition for the common builder;
% exposure events are forbidden for this layout, so overlap is never transmitted.
control=strcmp(cfg.partition.layout,'full64_imaging_control');
if control, exposure=mod(col,2)==0; end
if (~control && ~shared && sum(imaging)~=sum(exposure)) || ~any(imaging)
    error('icevs:Partition','The fixed physical partitions must be nonempty and equal.');
end
part=struct('layout',cfg.partition.layout,'imaging_mask',imaging,'exposure_mask',exposure, ...
    'imaging_count',sum(imaging),'exposure_count',sum(exposure),'column',col,'row',row, ...
    'boundary_x_wls',mid,'provenance',cfg.partition.provenance, ...
    'numbering_basis','Ascending physical x; column is physical rank for a linear array, not connector signal.');
imageApod=weights(cfg.imaging.apod,imaging);
exposureApod=weights(cfg.exposure.apod,exposure);
if shared && ~all(imageApod>0)
    error('icevs:Partition','Full64 imaging requires every imaging TX element to remain active.');
end
part.shared_count=sum(imaging & exposure);
part.imaging_active_mask=imageApod(:)>0;
part.exposure_active_mask=exposureApod(:)>0;
part.role_overlap_basis='Shared roles execute in separate events; exposure events have no acquisition.';
end
function a=weights(a,mask)
if isempty(a), a=double(mask'); return; end
a=reshape(a,1,[]);
if any(a(~mask)~=0) || ~any(a(mask)>0)
    error('icevs:Partition','Apodization cannot activate elements outside its configured role mask.');
end
end
