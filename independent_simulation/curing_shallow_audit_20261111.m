function [regions,comparison,support]=curing_shallow_audit_20261111()
%CURING_SHALLOW_AUDIT_20261111 Native-grid peak sensitivity and source support.
% Preserves z=0 and the whole 0-2mm layer; subdivisions are diagnostic only.
root=fileparts(mfilename('fullpath'));
base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
out=fullfile(base,'shallow_audit_20261111');
assert(~isfolder(out),'iceind:NoOverwrite','Shallow audit directory already exists.'); mkdir(out);
cases={'all64_dx65','all64_dx52','center16_dx65','center16_dx52'};
labels={'z0_source_plane','z_gt0_to_0p26','z_0p26_to_0p52', ...
    'z_0p52_to_1','z_1_to_2','z_2_to_5','z_0_to_2'};
rows=struct('case_name',{},'region',{},'voxels',{},'peak_pa',{},'peak_x_mm',{}, ...
    'peak_y_mm',{},'peak_z_mm',{},'qp_peak_pa2_s',{},'qp_x_mm',{},'qp_y_mm',{},'qp_z_mm',{});
supports=struct('case_name',{},'source_z_min_mm',{},'source_z_max_mm',{}, ...
    'source_plane_count',{},'source_points',{});
for k=1:numel(cases)
    a=load(fullfile(base,[cases{k} '_field.mat']),'p_amp','qp','x_m','y_m','z_m','meta');
    x=a.x_m(:); y=a.y_m(:); z=a.z_m(:); n=size(a.p_amp); pml=a.meta.pml_cells;
    fi=fullfile(base,[cases{k} '_gpu_io'],'field_input.h5');
    idx=double(h5read(fi,'/p_source_index'));
    [~,~,iz]=ind2sub(n+2*pml,idx); iz=iz-pml;
    assert(all(iz>=1 & iz<=n(3)),'iceind:ShallowAudit','Source extends outside physical grid.');
    sz=z(iz); supports(end+1)=struct('case_name',cases{k}, ...
        'source_z_min_mm',min(sz)*1e3,'source_z_max_mm',max(sz)*1e3, ...
        'source_plane_count',numel(unique(iz)),'source_points',numel(idx)); %#ok<AGROW>
    masks={abs(z)<1e-12,z>1e-12 & z<.26e-3-1e-12, ...
        z>=.26e-3-1e-12 & z<.52e-3-1e-12, ...
        z>=.52e-3-1e-12 & z<1e-3-1e-12, ...
        z>=1e-3-1e-12 & z<2e-3-1e-12, ...
        z>=2e-3-1e-12 & z<5e-3-1e-12,z>=-1e-12 & z<2e-3-1e-12};
    for j=1:numel(labels)
        zz=find(masks{j}); assert(~isempty(zz),'iceind:ShallowAudit','Empty layer.');
        p=a.p_amp(:,:,zz); q=a.qp(:,:,zz); [pv,pi]=max(p(:)); [qv,qi]=max(q(:));
        [px,py,pz]=ind2sub(size(p),pi); [qx,qy,qz]=ind2sub(size(q),qi);
        rows(end+1)=struct('case_name',cases{k},'region',labels{j},'voxels',numel(p), ...
            'peak_pa',double(pv),'peak_x_mm',x(px)*1e3,'peak_y_mm',y(py)*1e3,'peak_z_mm',z(zz(pz))*1e3, ...
            'qp_peak_pa2_s',double(qv),'qp_x_mm',x(qx)*1e3,'qp_y_mm',y(qy)*1e3,'qp_z_mm',z(zz(qz))*1e3); %#ok<AGROW>
    end
    clear a p q;
end
regions=struct2table(rows); support=struct2table(supports);
writetable(regions,fullfile(out,'native_peak_layers.csv'));
writetable(support,fullfile(out,'source_support.csv'));
cr=struct('variant',{},'region',{},'peak_change_percent',{},'qp_peak_change_percent',{});
for variant={'all64','center16'}
    for j=1:numel(labels)
        a=regions(strcmp(regions.case_name,[variant{1} '_dx65']) & strcmp(regions.region,labels{j}),:);
        b=regions(strcmp(regions.case_name,[variant{1} '_dx52']) & strcmp(regions.region,labels{j}),:);
        cr(end+1)=struct('variant',variant{1},'region',labels{j}, ...
            'peak_change_percent',100*(b.peak_pa/a.peak_pa-1), ...
            'qp_peak_change_percent',100*(b.qp_peak_pa2_s/a.qp_peak_pa2_s-1)); %#ok<AGROW>
    end
end
comparison=struct2table(cr); writetable(comparison,fullfile(out,'grid_peak_changes.csv'));
disp(support); disp(comparison);
end
