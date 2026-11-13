function out = curing_sparse_independent_readback_20261113()
% Read saved k-Wave inputs and fields without running propagation.
root = fileparts(mfilename('fullpath'));
folder = fullfile(root,'results','curing_field_2026-11-10','bli_gpu_full');
out = fullfile(root,'results','curing_sparse_2026-11-12','independent_audit_20261113');
assert(~isfolder(out),'iceind:NoOverwrite','Independent audit output already exists.');
gridUm = [65;52];
tags = {'all64','center32','odd32','even32'};
fieldRows = cell(8,17);
mirrorRows = cell(6,5);
sourceL2 = zeros(2,1);
row = 0;
mirrorRow = 0;
for g = 1:numel(gridUm)
    dx = gridUm(g);
    for k = 1:numel(tags)
        tag = sprintf('%s_dx%d',tags{k},dx);
        s = load(fullfile(folder,[tag '_field.mat']), ...
            'p_amp','qp','p_final','x_m','y_m','z_m','Nt','dt_s');
        n = size(s.p_amp);
        [~,iz0] = min(abs(s.z_m));
        [~,izt] = min(abs(s.z_m-0.020));
        [~,ix0] = min(abs(s.x_m));
        [~,iy0] = min(abs(s.y_m));
        [p0,p0idx] = max(s.p_amp(:,:,iz0),[],'all','linear');
        [p0x,p0y] = ind2sub(n(1:2),p0idx);
        [q0,q0idx] = max(s.qp(:,:,iz0),[],'all','linear');
        [q0x,q0y] = ind2sub(n(1:2),q0idx);
        forward = s.z_m>=0.002;
        inside = abs(s.x_m(:))<=0.002+1e-12 & abs(s.y_m(:)')<=0.002+1e-12 ...
            & reshape(abs(s.z_m-0.020)<=0.004+1e-12,1,1,[]);
        outside = ~inside & reshape(forward,1,1,[]);
        [qOutside,outsideIdx] = max(s.qp(outside));
        indices = find(outside);
        [ix,iy,iz] = ind2sub(n,indices(outsideIdx));
        pEqual = NaN;
        qEqual = NaN;
        finalEqual = NaN;
        if k>=3
            [pEqual,qEqual,finalEqual] = compareHdf5(folder,tag,s);
            assert(pEqual && qEqual && finalEqual, ...
                'iceind:SparseAudit','Field differs from HDF5 for %s.',tag);
        end
        row = row+1;
        fieldRows(row,:) = {tags{k},dx,double(pEqual),double(qEqual),double(finalEqual), ...
            s.p_amp(ix0,iy0,izt),s.qp(ix0,iy0,izt),p0, ...
            s.x_m(p0x)*1e3,s.y_m(p0y)*1e3,q0,s.x_m(q0x)*1e3,s.y_m(q0y)*1e3, ...
            qOutside,s.x_m(ix)*1e3,s.y_m(iy)*1e3,s.z_m(iz)*1e3};
        clear s outside inside indices
    end
    odd = load(fullfile(folder,sprintf('odd32_dx%d_field.mat',dx)), ...
        'p_amp','qp','x_m','y_m','z_m');
    even = load(fullfile(folder,sprintf('even32_dx%d_field.mat',dx)), ...
        'p_amp','qp','x_m','y_m','z_m');
    assert(isequal(odd.y_m,even.y_m) && isequal(odd.z_m,even.z_m));
    [found,reflected] = ismembertol(-odd.x_m,even.x_m,1e-12,'DataScale',1);
    oddIndex = find(found);
    evenIndex = reflected(found);
    assert(numel(oddIndex)==numel(odd.x_m)-1);
    for region = ["all","z_ge_2mm","target_box"]
        [xSelect,ySelect,zSelect] = regionIndices(odd,oddIndex,region);
        mirrorRow = mirrorRow+1;
        pL2 = relativeL2(odd.p_amp(oddIndex(xSelect),ySelect,zSelect), ...
            even.p_amp(evenIndex(xSelect),ySelect,zSelect));
        qL2 = relativeL2(odd.qp(oddIndex(xSelect),ySelect,zSelect), ...
            even.qp(evenIndex(xSelect),ySelect,zSelect));
        mirrorRows(mirrorRow,:) = {dx,region,numel(xSelect)*numel(ySelect)*numel(zSelect),pL2,qL2};
    end
    clear odd even
    sourceL2(g) = compareSources(folder,dx);
end
mkdir(out);
fields = cell2table(fieldRows,'VariableNames',{'variant','grid_um', ...
    'p_amp_hdf5_equal','qp_hdf5_equal','p_final_hdf5_equal', ...
    'target_p_assumed_pa','target_qp_assumed_pa2_s','source_plane_p_assumed_pa', ...
    'source_plane_p_x_mm','source_plane_p_y_mm','source_plane_qp_assumed_pa2_s', ...
    'source_plane_qp_x_mm','source_plane_qp_y_mm','outside_qp_assumed_pa2_s', ...
    'outside_qp_x_mm','outside_qp_y_mm','outside_qp_z_mm'});
mirrors = cell2table(mirrorRows,'VariableNames', ...
    {'grid_um','region','paired_voxels','p_amp_relative_l2','qp_relative_l2'});
sources = table(gridUm,sourceL2,'VariableNames',{'grid_um','odd_plus_even_vs_all64_relative_l2'});
writetable(fields,fullfile(out,'field_readback.csv'));
writetable(mirrors,fullfile(out,'mirror.csv'));
writetable(sources,fullfile(out,'source_sum.csv'));
disp(fields(:,1:7));
disp(mirrors);
disp(sources);
end

function [pEqual,qEqual,finalEqual] = compareHdf5(folder,tag,s)
run = fullfile(folder,[tag '_gpu_io']);
in = fullfile(run,'field_input.h5');
out = fullfile(run,'field_output.h5');
n = size(s.p_amp);
shape = double([h5read(in,'/Nx') h5read(in,'/Ny') h5read(in,'/Nz')]);
pml = double([h5read(in,'/pml_x_size') h5read(in,'/pml_y_size') h5read(in,'/pml_z_size')]);
start = pml+1;
assert(isequal(n+2*pml,shape) && h5read(in,'/Nt')==s.Nt ...
    && abs(h5read(in,'/dt')-s.dt_s)<1e-15);
sensor = reshape(h5read(in,'/sensor_mask_index'),n);
[xx,yy] = ndgrid(start(1):shape(1)-pml(1),start(2):shape(2)-pml(2));
base = uint64(xx+(yy-1)*shape(1));
for iz = 1:n(3)
    assert(isequal(sensor(:,:,iz),base+uint64((iz+pml(3)-1)*shape(1)*shape(2))));
end
clear sensor
pEqual = isequal(s.p_amp,max(h5read(out,'/p_max_all',start,n),-h5read(out,'/p_min_all',start,n)));
rmsPressure = h5read(out,'/p_rms');
qEqual = isequal(s.qp,reshape(single(double(rmsPressure).^2*double(s.Nt)*s.dt_s),n));
finalEqual = isequal(s.p_final,h5read(out,'/p_final',start,n));
end

function [x,y,z] = regionIndices(s,oddIndex,region)
x = 1:numel(oddIndex);
y = 1:numel(s.y_m);
z = 1:numel(s.z_m);
if region=="z_ge_2mm"
    z = find(s.z_m>=0.002);
elseif region=="target_box"
    x = find(abs(s.x_m(oddIndex))<=0.002+1e-12);
    y = find(abs(s.y_m)<=0.002+1e-12);
    z = find(abs(s.z_m-0.020)<=0.004+1e-12);
end
end

function result = compareSources(folder,dx)
tags = {'all64','odd32','even32'};
pressure = cell(1,3);
index = cell(1,3);
for k = 1:3
    file = fullfile(folder,sprintf('%s_dx%d_gpu_io',tags{k},dx),'field_input.h5');
    pressure{k} = h5read(file,'/p_source_input');
    index{k} = h5read(file,'/p_source_index');
    assert(size(pressure{k},1)==numel(index{k}));
end
[foundOdd,oddRows] = ismember(index{2},index{1});
[foundEven,evenRows] = ismember(index{3},index{1});
assert(all(foundOdd) && all(foundEven));
combined = zeros(size(pressure{1}),'like',pressure{1});
combined(oddRows,:) = pressure{2};
combined(evenRows,:) = combined(evenRows,:)+pressure{3};
result = relativeL2(pressure{1},combined);
end

function result = relativeL2(reference,value)
result = norm(double(reference(:))-double(value(:)))/norm(double(reference(:)));
end
