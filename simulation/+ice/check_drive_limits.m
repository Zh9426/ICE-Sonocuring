function assessment = check_drive_limits(cfg, geom, sequence)
%CHECK_DRIVE_LIMITS Compare declared numerical inputs to explicit limits.
% No voltage, electric power, radiated power, or probe heating is inferred.
if ~isstruct(cfg) || ~all(isfield(cfg,{'source','exposure'})) || ...
        ~isstruct(geom) || ~isfield(geom,'positions_m') || ...
        ~isstruct(sequence) || ~isfield(sequence,'shots') || isempty(sequence.shots)
    error('ice:HardwareLimits','Configuration, geometry and sequence are required.');
end
n=size(geom.positions_m,1);
used=false(n,1);peak_weight=0;
for j=1:numel(sequence.shots)
    w=sequence.shots(j).weights;
    if ~isnumeric(w) || ~isequal(size(w),[n 1]) || any(~isfinite(w))
        error('ice:HardwareLimits','Every shot needs finite N-by-1 weights.');
    end
    used=used | abs(w)>0;
    peak_weight=max(peak_weight,max(abs(w)));
end
observed=struct('max_element_velocity_m_s',cfg.source.velocity_m_s*peak_weight, ...
    'duty_cycle',cfg.exposure.duty_cycle, ...
    'exposure_time_s',cfg.exposure.exposure_time_s, ...
    'total_channels',n,'curing_channels',nnz(used));
names={'max_element_velocity_m_s','max_duty_cycle','max_exposure_time_s', ...
    'max_total_channels','max_curing_channels'};
observed_names={'max_element_velocity_m_s','duty_cycle','exposure_time_s', ...
    'total_channels','curing_channels'};
limits=struct();failed={};specified=0;
if ~isfield(cfg,'hardware')
    hardware=struct();
elseif ~isstruct(cfg.hardware) || ~isscalar(cfg.hardware)
    error('ice:HardwareLimits','hardware must be a scalar structure.');
else
    hardware=cfg.hardware;
end
for j=1:numel(names)
    key=names{j};limit=NaN;
    if isfield(hardware,key) && ~isempty(hardware.(key))
        limit=hardware.(key);
        if ~isnumeric(limit) || ~isreal(limit) || ~isscalar(limit) || ...
                (~isnan(limit) && (~isfinite(limit) || limit<0)) || ...
                (~isnan(limit) && j>=4 && (limit<1 || limit~=fix(limit))) || ...
                (~isnan(limit) && j==2 && limit>1)
            error('ice:HardwareLimits','Invalid limit %s.',key);
        end
    end
    limits.(key)=limit;
    if isfinite(limit)
        specified=specified+1;
        if observed.(observed_names{j})>limit
            failed{end+1}=key; %#ok<AGROW>
        end
    end
end
status='unknown';
if ~isempty(failed),status='fail';
elseif specified>0,status='pass';end
assessment=struct('status',status,'observed',observed,'limits',limits, ...
    'failed_limits',{failed},'specified_limit_count',specified, ...
    'source_calibrated',cfg.source.calibrated, ...
    'interpretation',['Numerical input-limit check only; no measured device ' ...
    'output, radiated power, voltage, or thermal feasibility claim.']);
end
