function [metrics,regions]=curing_combine_metrics_20261111()
%CURING_COMBINE_METRICS_20261111 Combine four existing analyzed GPU cases.
root=fileparts(mfilename('fullpath'));
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
cases={'all64_dx65','all64_dx52','center16_dx65','center16_dx52'};
metricCells=cell(numel(cases),1); regionCells=metricCells;
for k=1:numel(cases)
    dir=fullfile(base,['analysis_' cases{k}]);
    metricCells{k}=readtable(fullfile(dir,'metrics.csv'));
    r=readtable(fullfile(dir,'axial_regions.csv'));
    r.case_name=repmat(string(cases{k}),height(r),1);
    regionCells{k}=movevars(r,'case_name','Before',1);
end
metrics=vertcat(metricCells{:}); regions=vertcat(regionCells{:});
dest1=fullfile(base,'combined_metrics.csv'); dest2=fullfile(base,'combined_axial_regions.csv');
assert(~isfile(dest1) && ~isfile(dest2),'iceind:NoOverwrite','Combined output already exists.');
writetable(metrics,dest1); writetable(regions,dest2); disp(metrics);
end
