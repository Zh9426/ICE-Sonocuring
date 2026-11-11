function result=curing_source_alignment_20261111()
%CURING_SOURCE_ALIGNMENT_20261111 Native source-plane peak/grid alignment.
% Model geometry is existing-code-unverified; this is not a measured hotspot.
root=fileparts(mfilename('fullpath')); addpath(root);
base=fullfile(root,'results','curing_field_2026-11-10');
rows=struct('variant',{},'grid',{},'dx_um',{},'qp_peak_pa2_s',{}, ...
    'x_mm',{},'y_mm',{},'nearest_rank',{},'nearest_center_x_mm',{}, ...
    'x_offset_from_center_um',{},'element_width_um',{},'element_height_um',{});
drivers=struct('All64','ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat', ...
    'Center16','ICE_CuringOnly_Exposure000000FFFF000000_exposure_only.mat');
for variant={'All64','Center16'}
    d=load(fullfile(base,'..','curing_export_2026-11-10',drivers.(variant{1})));
    compiled=iceind.compile_kwave(d); active=find(compiled.tx(1).apod~=0);
    for grid={'dx65','dx52','dx43p333','dx32p5'}
        if ismember(grid{1},{'dx65','dx52'})
            path=fullfile(base,'bli_gpu_full',[lower(variant{1}) '_' grid{1} '_field.mat']);
        else
            path=fullfile(base,'bli_gpu_shallow',[lower(variant{1}) '_' grid{1} '_field.mat']);
        end
        if ~isfile(path), continue; end
        s=load(path,'qp','x_m','y_m','z_m'); x=s.x_m(:); y=s.y_m(:); z=s.z_m(:);
        [dist,iz]=min(abs(z)); assert(dist<1e-12,'iceind:Alignment','No source plane grid.');
        plane=s.qp(:,:,iz); [v,ind]=max(plane(:)); [ix,iy]=ind2sub(size(plane),ind);
        [~,near]=min(abs(compiled.geometry.positions_m(active,1)-x(ix))); rank=active(near);
        dx=mean(diff(x)); cx=compiled.geometry.positions_m(rank,1);
        rows(end+1)=struct('variant',variant{1},'grid',grid{1},'dx_um',dx*1e6, ...
            'qp_peak_pa2_s',double(v),'x_mm',x(ix)*1e3,'y_mm',y(iy)*1e3, ...
            'nearest_rank',rank,'nearest_center_x_mm',cx*1e3, ...
            'x_offset_from_center_um',(x(ix)-cx)*1e6, ...
            'element_width_um',compiled.geometry.width_m*1e6, ...
            'element_height_um',compiled.geometry.height_m*1e6); %#ok<AGROW>
    end
end
result=struct2table(rows); dest=fullfile(base,'bli_gpu_shallow','source_plane_alignment.csv');
assert(~isfile(dest),'iceind:NoOverwrite','Alignment table exists.');
writetable(result,dest); disp(result);
end
