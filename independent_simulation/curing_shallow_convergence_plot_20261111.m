function curing_shallow_convergence_plot_20261111()
%CURING_SHALLOW_CONVERGENCE_PLOT_20261111 Plot source-plane native maxima.
root=fileparts(mfilename('fullpath'));
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_shallow');
t=readtable(fullfile(base,'source_plane_alignment_5grid.csv'));
out=fullfile(base,'source_plane_grid_sensitivity.png');
assert(~isfile(out),'iceind:NoOverwrite','Plot exists; inspect it first.');
fig=figure('Visible','off','Color','w','Position',[50 50 900 560]); hold on;
for variant={'All64','Center16'}
    a=t(strcmp(t.variant,variant{1}),:); a=sortrows(a,'dx_um','descend');
    plot(a.dx_um,a.qp_peak_pa2_s*1e6,'-o','LineWidth',1.5,'MarkerSize',6,'DisplayName',variant{1});
end
set(gca,'XDir','reverse'); grid on; xlabel('Grid spacing (micrometres; finer to right)');
ylabel('Source-plane max Qp (10^{-6} assumed Pa^2 s)');
title('One-pulse model: source-plane grid sensitivity'); legend('Location','best');
exportgraphics(fig,out,'Resolution',150); close(fig);
end
