function comparison=curing_bli_propagation_compare_20261110()
%CURING_BLI_PROPAGATION_COMPARE_20261110 Five common points, diagnostic only.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'results','curing_field_2026-11-10','bli_propagation_probe');
src=readtable(fullfile(out,'point_trace_metrics.csv'));
coarse=sortrows(src(src.dx_um==65,:),'point_index');
fine=sortrows(src(src.dx_um==52,:),'point_index');
assert(height(coarse)==5 && height(fine)==5 && ...
    isequal(coarse{:,{'point_index','x_mm','y_mm','z_mm'}}, ...
            fine{:,{'point_index','x_mm','y_mm','z_mm'}}),'iceind:ProbeGeometry', ...
    'The two grids must have the same five physical points.');
comparison=coarse(:,{'point_index','x_mm','y_mm','z_mm'});
comparison.peak65_assumed_pa=coarse.peak_assumed_pa;
comparison.peak52_assumed_pa=fine.peak_assumed_pa;
comparison.peak_change_percent=100*(fine.peak_assumed_pa./coarse.peak_assumed_pa-1);
comparison.qp65_assumed_pa2_s=coarse.qp_assumed_pa2_s;
comparison.qp52_assumed_pa2_s=fine.qp_assumed_pa2_s;
comparison.qp_change_percent=100*(fine.qp_assumed_pa2_s./coarse.qp_assumed_pa2_s-1);
comparison.tail65_over_peak=coarse.tail_over_peak;
comparison.tail52_over_peak=fine.tail_over_peak;
writetable(comparison,fullfile(out,'common_points_comparison.csv'));
fprintf('Largest absolute peak change %.3f%%; Qp change %.3f%%; last-20-sample tail/peak %.3f%%.\n', ...
    max(abs(comparison.peak_change_percent)),max(abs(comparison.qp_change_percent)), ...
    100*max([coarse.tail_over_peak;fine.tail_over_peak]));
end
