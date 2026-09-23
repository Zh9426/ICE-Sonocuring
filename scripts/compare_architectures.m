function summary = compare_architectures(cfg, output_dir)
%COMPARE_ARCHITECTURES 5 apertures x 3 modes; fixed source and common reference.
% cfg is optional. For a different geometry/normalization pass a full config.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin<1||isempty(cfg),cfg=demo_config('linear');end
if nargin<2,output_dir=fullfile(root,'results',['architectures_' cfg.array.type]);end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
base=cfg;base.architecture.type='shared';base.excitation.mode='focused';base.excitation.dwell_weights=[];
baseline=ice.simulate(base);reference=baseline.reference;
patterns={'shared','central_curing','peripheral_curing','checkerboard','random_sparse'};
modes={'focused','broad','expanded'};rows=cell(15,1);configs=cell(15,1);idx=0;
for m=1:numel(modes)
    for j=1:numel(patterns)
        candidate=cfg;candidate.excitation.mode=modes{m};
        if j==1,candidate.architecture.type='shared';
        else,candidate.architecture.type='partitioned';candidate.architecture.pattern=patterns{j};end
        result=ice.simulate(candidate,reference);idx=idx+1;configs{idx}=candidate;
        name=[modes{m} '_' patterns{j}];rows{idx}=ice.summary_row(result,name);
        if m==1
            fig=ice.plot_result(result,fullfile(output_dir,[name '.png']));close(fig);
        end
        fprintf('Architecture %2d/15 %s C=%.3f L=%.3f\n',idx,name,result.metrics.target_coverage,result.metrics.off_target_exposure);
    end
end
summary=struct2table([rows{:}]);writetable(summary,fullfile(output_dir,'comparison.csv'));
save(fullfile(output_dir,'comparison_config.mat'),'configs','reference','summary');
fig=figure('Visible',cfg.output.visible,'Color','w','Position',[100 100 1200 550]);
tiledlayout(1,2,'Padding','compact');
nexttile;bar(reshape(summary.target_coverage,5,3));ylim([0 1]);ylabel('Target coverage');
xticks(1:5);xticklabels(patterns);xtickangle(20);set(gca,'TickLabelInterpreter','none');legend(modes,'Location','best');
nexttile;bar(reshape(summary.off_target_exposure,5,3));ylabel('Off-target fraction within sampled ROI');
xticks(1:5);xticklabels(patterns);xtickangle(20);set(gca,'TickLabelInterpreter','none');
sgtitle(sprintf('SYNTHETIC %s | %s | common shared-focused threshold',cfg.array.type,cfg.excitation.normalization),'Interpreter','none');
exportgraphics(fig,fullfile(output_dir,'comparison.png'),'Resolution',160);close(fig);
end
