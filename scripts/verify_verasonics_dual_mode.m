function summary = verify_verasonics_dual_mode()
%VERIFY_VERASONICS_DUAL_MODE Offline artifact generation and code analysis.
% Unit/regression tests are executed separately by run_tests.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'verasonics','dual_mode'));
out=fullfile(root,'results','verasonics_full64_selected_exposure');
if ~isfolder(out), mkdir(out); end
modes={'imaging_only','exposure_only','interleaved'};
rows=struct('mode',{},'events',{},'imaging_acquisitions',{},'exposure_pulses',{}, ...
    'scheduled_cycle_us',{},'scheduled_total_us',{},'nominal_duty',{},'buffer_mib',{});
for k=1:numel(modes)
    cfg=icevs.default_config(root); cfg.mode=modes{k};
    [seq,r]=SetUpICE_ImagingCuring(cfg,out);
    rows(k)=struct('mode',cfg.mode,'events',numel(seq.Event), ...
        'imaging_acquisitions',r.timing.total_imaging_acquisitions, ...
        'exposure_pulses',r.timing.total_exposure_pulses, ...
        'scheduled_cycle_us',r.timing.scheduled_cycle_us, ...
        'scheduled_total_us',r.timing.scheduled_total_us, ...
        'nominal_duty',r.timing.nominal_exposure_duty_cycle, ...
        'buffer_mib',r.reserved_receive_buffer_mib);
end
summary=struct2table(rows);
writetable(summary,fullfile(out,'mode_summary.csv'));
files=[dir(fullfile(root,'verasonics','dual_mode','**','*.m')); ...
    dir(fullfile(root,'tests','test_verasonics_*.m')); ...
    dir(fullfile(root,'scripts','verify_verasonics_dual_mode.m'))];
analysis=struct('file',{},'messages',{});
for k=1:numel(files)
    file=fullfile(files(k).folder,files(k).name);
    analysis(k)=struct('file',file,'messages',checkcode(file,'-id'));
end
fid=fopen(fullfile(out,'code_analysis.json'),'w','n','UTF-8');
closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(struct('matlab_version',version,'files',analysis),'PrettyPrint',true),'char');
disp(summary);
fprintf('Code Analyzer: %d messages across %d files.\n',sum(arrayfun(@(a)numel(a.messages),analysis)),numel(files));
fig=figure('Visible','off','Color','w','Position',[100 100 1080 280]);
closeFigure=onCleanup(@()close(fig));
[~,physicalOrder]=sort(seq.Trans.ElementPos(:,1));
imagesc(1:64,1:2,double([r.partition.imaging_mask(physicalOrder)'; ...
    r.partition.exposure_mask(physicalOrder)']));
set(gca,'YDir','normal','XTick',[1 8 16 24 32 40 48 56 64], ...
    'YTick',[1 2],'YTickLabel',{'Imaging TX/RX','Exposure TX'},'FontSize',12);
pbaspect([8 1 1]);
colormap([.92 .92 .92;.35 .7 .85]);
for edge=1.5:63.5, xline(edge,'w','LineWidth',.3); end
title({'Full64 imaging and selected-element exposure: active (blue), inactive (gray)', ...
    'Roles overlap in elements, not in acquisition time; mapping requires bench verification'});
xlabel('Physical element rank along +x (default logical order 1:64)');
exportgraphics(fig,fullfile(out,'aperture_roles.png'),'Resolution',150);
end
