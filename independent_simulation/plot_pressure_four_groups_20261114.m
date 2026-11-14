% Replot saved profiles only; no acoustic solver or hardware is used.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'results','pressure_evidence_20261114');
u=readtable(fullfile(out,'ucl_axis_profiles.csv'));
uz=u.scan_depth_from_origin_mm; up=u.peak_line_abs_over_max;
[~,iu]=max(up); uz=uz-uz(iu);
names={'All64','Center48','Center32','Odd32'};
colors={[.84 .37 0],[.9 .62 0],[.48 .2 .58],[0 .45 .7]};
fig=figure('Visible','off','Color','w','Position',[50 50 1250 800]);
t=tiledlayout(fig,2,2,'TileSpacing','compact'); profiles=cell(1,4);
for n=1:4
    path=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full', ...
        ['analysis_' lower(names{n}) '_dx52'],'profile_z.csv');
    a=readtable(path); keep=a.coordinate_mm>=2 & a.coordinate_mm<=29.9;
    z=a.coordinate_mm(keep); p=a.peak_assumed_pa(keep);
    [pmax,ip]=max(p); peak_z=z(ip); p=p/pmax; profiles{n}=p;
    ax=nexttile(t); hold(ax,'on');
    plot(ax,uz,up,'k-','LineWidth',2,'DisplayName','UCL measured peak line');
    plot(ax,z-peak_z,p,'--','Color',colors{n},'LineWidth',2,'DisplayName',[names{n} ' simulated']);
    yline(ax,10^(-6/20),':','HandleVisibility','off');
    title(ax,sprintf('%s: simulated peak z = %.3f mm',names{n},peak_z));
    xlim(ax,[-15 18]); ylim(ax,[0 1.08]); grid(ax,'on'); legend(ax,'Location','southwest');
end
xlabel(t,'Depth relative to each profile maximum (mm)');
ylabel(t,'Peak |p(t)| / own profile maximum');
title(t,'Four layouts vs UCL measurement: peak-aligned shape only');
subtitle(t,'Different devices and pulses; alignment removes absolute focus position. UCL depth origin unknown.');
exportgraphics(fig,fullfile(out,'ucl_four_selected_profiles.png'),'Resolution',160); close(fig);
fprintf('All64 vs Odd32 max normalized difference: %.9g\n',max(abs(profiles{1}-profiles{4})));
