function report=run_independent_demo()
%RUN_INDEPENDENT_DEMO Isolated synthetic point-target RF and DAS benchmark.
root=fileparts(mfilename('fullpath'));
old=path; cleanup=onCleanup(@()path(old));
addpath(root);
out=fullfile(root,'results'); if ~isfolder(out), mkdir(out); end
cfg=iceind.default_config();
data=iceind.simulate_rf(cfg); result=iceind.reconstruct(data,cfg);
err=norm(result.peak_xz_m-cfg.target.xz_m);
grid=hypot(diff(cfg.image.x_m(1:2)),diff(cfg.image.z_m(1:2)));
report=struct('matlab',version,'solver',cfg.model.name, ...
    'provenance','synthetic','amplitude_units','arbitrary', ...
    'target_mm',cfg.target.xz_m*1000,'peak_mm',result.peak_xz_m*1000, ...
    'localization_error_mm',err*1000,'grid_diagonal_mm',grid*1000, ...
    'internal_localization_check_passed',err<=grid, ...
    'physical_validation','unknown','vsx_compatibility','not_tested', ...
    'finite_aperture_transmit','not_modeled','curing','not_modeled');
save(fullfile(out,'point_target.mat'),'cfg','data','result','report');
fid=fopen(fullfile(out,'point_target_report.json'),'w'); assert(fid>=0);
fwrite(fid,jsonencode(struct('report',report,'config',cfg),'PrettyPrint',true),'char'); fclose(fid);
f=figure('Visible','off','Color','w','Position',[100 100 1200 500]);
figCleanup=onCleanup(@()close(f));
tiledlayout(1,2,'Padding','compact');
nexttile;
imagesc(1:size(data.rf,2),data.time_s*1e6,data.rf); ylim([24 29]);
xlabel('Receive element'); ylabel('Time (us)');
title('Synthetic RF | arbitrary amplitude'); colorbar;
nexttile;
imagesc(result.x_m*1000,result.z_m*1000,result.db);
axis image; clim([-cfg.image.dynamic_range_db 0]);
colormap(gca,gray(256)); cb=colorbar; cb.Label.String='Relative envelope (dB)';
hold on;
plot(cfg.target.xz_m(1)*1000,cfg.target.xz_m(2)*1000,'rx','LineWidth',1.5,'MarkerSize',10);
plot(result.peak_xz_m(1)*1000,result.peak_xz_m(2)*1000,'co','LineWidth',1.3,'MarkerSize',9);
xlabel('x (mm)'); ylabel('z (mm)');
title(sprintf('DAS | localization error %.4f mm',err*1000));
legend('Synthetic target','Image peak','Location','southwest');
sgtitle('Ideal plane-wave benchmark | uncalibrated | no curing model');
exportgraphics(f,fullfile(out,'point_target.png'),'Resolution',160);
disp(report);
assert(report.internal_localization_check_passed,'iceind:Localization', ...
    'Internal localization error exceeds one grid diagonal.');
end
