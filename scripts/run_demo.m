function summary = run_demo(output_dir)
%RUN_DEMO Six synthetic linear/matrix x focused/broad/expanded 3-D examples.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin==0,output_dir=fullfile(root,'results','demo');end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
types={'linear','matrix'};modes={'focused','broad','expanded'};rows=cell(0,1);
for a=1:numel(types)
    cfg=demo_config(types{a});baseline=ice.simulate(cfg);ref=baseline.reference;
    for m=1:numel(modes)
        cfg.excitation.mode=modes{m};
        if m==1,result=baseline;else,result=ice.simulate(cfg,ref);end
        name=[types{a} '_' modes{m}];
        fig=ice.plot_result(result,fullfile(output_dir,[name '.png']));close(fig);
        save(fullfile(output_dir,[name '.mat']),'result');
        iceio.export_handoff(result.geometry,result.sequence,cfg,fullfile(output_dir,[name '_handoff.json']));
        rows{end+1}=ice.summary_row(result,name); %#ok<AGROW>
        fprintf('Demo %s: C=%.3f L=%.3f\n',name,result.metrics.target_coverage,result.metrics.off_target_exposure);
    end
end
summary=struct2table([rows{:}]);writetable(summary,fullfile(output_dir,'summary.csv'));
end
