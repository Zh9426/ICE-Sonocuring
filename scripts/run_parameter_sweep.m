function summary = run_parameter_sweep(cfg, field_path, values, output_dir)
%RUN_PARAMETER_SWEEP One-factor sweep with fixed baseline threshold reference.
% e.g. run_parameter_sweep(cfg,'acoustics.frequency_hz',[1.5 2.5 3.5]*1e6)
% Supports one numeric field one level below cfg. Geometry/grid changes need
% separate baselines if the intended comparison changes the physical ROI.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin<1||isempty(cfg),cfg=demo_config('linear');end
if nargin<2,field_path='acoustics.frequency_hz';end
if nargin<3,values=[1.5 2 2.5 3 3.5]*1e6;end
if nargin<4,output_dir=fullfile(root,'results','sweep');end
parts=strsplit(char(field_path),'.');
if numel(parts)~=2||~isfield(cfg,parts{1})||~isfield(cfg.(parts{1}),parts{2})|| ...
        ~isnumeric(values)||~isreal(values)||~isvector(values)||isempty(values)||any(~isfinite(values))
    error('ice:InvalidSweep','Use a known section.field and a finite numeric vector.');
end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
baseline=ice.simulate(cfg);reference=baseline.reference;rows=cell(numel(values),1);configs=cell(numel(values),1);
for j=1:numel(values)
    candidate=cfg;candidate.(parts{1}).(parts{2})=values(j);configs{j}=candidate;
    result=ice.simulate(candidate,reference);rows{j}=ice.summary_row(result,sprintf('%s=%g',field_path,values(j)));
    fprintf('Sweep %d/%d %s=%g\n',j,numel(values),field_path,values(j));
end
summary=struct2table([rows{:}]);summary.sweep_value=values(:);
writetable(summary,fullfile(output_dir,'sweep.csv'));
save(fullfile(output_dir,'sweep_config.mat'),'configs','reference','summary','field_path');
end
