function summary = run_p0_probe_compare(output_dir)
%RUN_P0_PROBE_COMPARE Synthetic 96+96 versus contiguous 96/96 partition.
% Both candidates use 192 model elements, 96 curing elements, the same
% frequency, source velocity, focus, ROI, threshold and solver sampling.
% Their physical x pitch layout differs, so this is not a causal claim that
% one architecture is superior or a prediction for an actual ICE device.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin<1 || isempty(output_dir)
    output_dir=fullfile(root,'results','p0_probe_compare');
end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
dual=synthetic_dual_96_config();
dual.excitation.mode='single_focus';
dual.grid=struct('x_m',linspace(-.0045,.0045,31), ...
    'y_m',linspace(-.003,.003,21),'z_m',linspace(.010,.020,31));
dual.target=struct('center_m',[.002 0 .015], ...
    'radii_m',[.001 .001 .001]);
dual.threshold.value=.25; % Synthetic common-reference screening threshold.
dual.solver.patch_count=[2 2];
partitioned=dual;
partitioned=rmfield(partitioned,'probe');
partitioned.array=dual.probe.curing.array;
partitioned.array.size=[24 8];
partitioned.architecture.type='partitioned';
partitioned.architecture.pattern='right_curing';
partitioned.architecture.curing_fraction=.5;
partitioned.provenance.description=['Synthetic single 24x8 array with contiguous right ' ...
    'half curing; matched model channel counts, not measured device geometry.'];
baseline=dual;baseline.architecture.type='shared';
reference_run=ice.simulate(baseline);
reference=reference_run.reference;
configs={dual,partitioned};
names={'dual_96_plus_96','partitioned_24x8_right_96'};
rows=cell(1,2);
results=cell(1,2);
for j=1:2
    r=ice.simulate(configs{j},reference);
    results{j}=r;
    rows{j}=ice.summary_row(r,names{j});
    fig=ice.plot_result(r,fullfile(output_dir,[names{j} '.png']));close(fig);
    fprintf('%s: C=%.3f, L=%.3f, post peak=%.1f Pa, drive=%s\n', ...
        names{j},r.metrics.target_coverage,r.metrics.off_target_exposure, ...
        r.safety.postfocal_max_pressure_pa,r.feasibility.status);
end
summary=struct2table([rows{:}]);
writetable(summary,fullfile(output_dir,'comparison.csv'));
levels=[.25 .35 .5];
sensitivity=cell(numel(levels)*numel(results),1);index=0;
for j=1:numel(results)
    r=results{j};
    for k=1:numel(levels)
        th=r.cfg.threshold;th.value=levels(k);
        m=ice.evaluate_threshold(r.exposure,r.target_mask,r.grid.voxel_volume_m3, ...
            th,r.cfg.source,reference);
        index=index+1;
        sensitivity{index}=struct('case_name',string(names{j}), ...
            'relative_threshold',levels(k),'threshold_pa',m.threshold_value_si, ...
            'target_coverage',m.target_coverage, ...
            'off_target_exposure',m.off_target_exposure);
    end
end
sensitivity=struct2table([sensitivity{:}]);
writetable(sensitivity,fullfile(output_dir,'threshold_sensitivity.csv'));
assumptions=struct('kind','synthetic','reference','dual shared full aperture', ...
    'claim','screening comparison only; differing x layouts and uncalibrated source');
save(fullfile(output_dir,'comparison_config.mat'),'configs','reference','summary', ...
    'sensitivity','results','assumptions');
end
