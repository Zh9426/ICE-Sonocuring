% PRESSURE_UCL_COMPARE_20261114  Compare existing data; no wave propagation.
% UCL CC BY 4.0 dataset DOI 10.5522/04/20005562.v1, study-3 dataset1.
% Local UCL file is not committed. Distances in that scan start at an
% unspecified scan origin, not a measured distance from the transducer.

root = fileparts(mfilename('fullpath'));
src = fullfile(root,'results','pressure_comparison_local_20261114','ucl_water_yz.h5');
out = fullfile(root,'results','pressure_evidence_20261114');
assert(isfile(src),'Download the documented UCL study-3 HDF5 first.');
if ~isfolder(out), mkdir(out); end
base = '/data/dataset1/scanData/';
sz = double(h5read(src,[base 'scanSize']));
assert(isequal(sz(:)',[100 300]),'Unexpected scan size or data ordering.');
coords = h5read(src,[base 'scanCoordinates']);
coords = reshape(coords,sz(1),sz(2),3);
y = double(squeeze(coords(:,1,2)))*1e3;
z = double(squeeze(coords(1,:,3)))*1e3;
assert(all(diff(y)>0) && all(diff(z)>0),'Unexpected scan coordinates.');
resp = double(h5read(src,'/sensor/sensorProperties/frequencyResponse'));
assert(resp(2)>0,'Invalid hydrophone sensitivity.');
info = h5info(src,[base 'waveformData']);
assert(info.Dataspace.Size(1)==prod(sz),'Unexpected waveform indexing.');
wave = h5read(src,[base 'waveformData']);
peak_abs = reshape(max(abs(wave),[],2),sz(1),sz(2))/resp(2);
peak_pos = reshape(max(wave,[],2),sz(1),sz(2))/resp(2);
peak_neg = reshape(-min(wave,[],2),sz(1),sz(2))/resp(2);
clear wave
assert(all(isfinite(peak_abs),'all') && max(peak_abs,[],'all')>0);
[~,iy] = min(abs(y));
assert(abs(y(iy))<1e-4,'Scan has no zero lateral coordinate.');
[v2,k2] = max(peak_abs,[],'all');
[iy2,iz2] = ind2sub(size(peak_abs),k2);
% Scan origin is not a verified acoustic centre. Retain the nominal-zero
% line and also inspect the fixed line through the plane-wide measured peak.
ext = double(peak_abs(iy2,:))';
ext_pos = double(peak_pos(iy2,:))';
ext_zero = double(peak_abs(iy,:))';
[v,j] = max(ext);
[vp,jp] = max(ext_pos);
rows = table(z(:),ext,ext/v,ext_pos,ext_pos/vp,ext_zero, ...
    'VariableNames',{'scan_depth_from_origin_mm','peak_line_abs_pa','peak_line_abs_over_max','peak_line_positive_pa','peak_line_positive_over_max','coordinate_zero_abs_pa'});
writetable(rows,fullfile(out,'ucl_axis_profiles.csv'));
save(fullfile(out,'ucl_pressure_maps.mat'),'y','z','peak_abs','peak_pos','peak_neg','resp','-v7');
fprintf('UCL sensitivity %.12g V/Pa; peak line y %.4f mm, abs %.9g Pa at scan z %.4f mm; positive %.9g Pa at %.4f mm\n',resp(2),y(iy2),v,z(j),vp,z(jp));
fprintf('UCL plane max abs %.9g Pa at y %.4f scan z %.4f mm; border=%d\n',v2,y(iy2),z(iz2),iy2==1||iy2==numel(y)||iz2==1||iz2==numel(z));

names={'All64','Center48','Center32','Center16','Odd32','Even32'};
fig=figure('Visible','off','Color','w','Position',[50 50 1250 540]);
tl=tiledlayout(fig,1,2,'TileSpacing','compact');
nexttile(tl); imagesc(z,y,double(peak_abs)/double(v2)); axis xy; colormap(turbo); colorbar;
xlabel('Scan depth from unknown origin (mm)'); ylabel('Lateral coordinate y (mm)');
title('UCL water measurement: max |p(t)| / plane maximum');
nexttile(tl); hold on;
plot(z(:)-z(j),ext/v,'k','LineWidth',2.3,'DisplayName','UCL measured 32, peak line');
summary=cell(numel(names),4);
offsets=[-5 0 5 10];
samples=nan(numel(names)+1,numel(offsets));
samples(1,:)=interp1(z(:)-z(j),ext/v,offsets,'linear',NaN);
for n=1:numel(names)
    f=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full', ...
        ['analysis_' lower(names{n}) '_dx52'],'profile_z.csv');
    tab=readtable(f); keep=tab.coordinate_mm>=2 & tab.coordinate_mm<=29.9;
    a=tab.coordinate_mm(keep); p=tab.peak_assumed_pa(keep);
    [maxp,im]=max(p);
    assert(isfinite(maxp) && maxp>0);
    plot(a-a(im),p/maxp,'LineWidth',1.2,'DisplayName',names{n});
    samples(n+1,:)=interp1(a-a(im),p/maxp,offsets,'linear',NaN);
    summary(n,:)={names{n},a(im),maxp,numel(a)};
end
xlabel('Depth relative to each axis maximum (mm)'); ylabel('Axial max |p(t)| / own axis maximum');
title('Exploratory peak-aligned shape; cannot assess focal shift'); grid on; xlim([-15 18]); ylim([0 1.08]);
legend('Location','southwest','FontSize',8);
exportgraphics(fig,fullfile(out,'ucl_project_pressure_profiles.png'),'Resolution',160);
close(fig);
writetable(cell2table(summary,'VariableNames',{'variant','axis_max_z_mm','axis_max_assumed_pa','n_samples'}), ...
    fullfile(out,'project_axis_peaks.csv'));
writetable(table([{'UCL_measured_peak_line'},names]',samples(:,1),samples(:,2),samples(:,3),samples(:,4), ...
    'VariableNames',{'profile','minus5mm','at_peak','plus5mm','plus10mm'}), ...
    fullfile(out,'exploratory_peak_aligned_samples.csv'));
fprintf('Saved axis and normalized shape outputs to %s\n',out);
