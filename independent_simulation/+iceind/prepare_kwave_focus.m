function [kg,medium,source,sensor,m,wave]=prepare_kwave_focus(c)
%PREPARE_KWAVE_FOCUS Read saved odd/even TX, map physical rectangular sources.
% No vendor execution or voltage-to-pressure conversion. SI units throughout.
s=load(c.input_mat);
assert(strcmp(s.ICEConfig.partition.layout,'odd_imaging_even_exposure'), ...
    'iceind:Partition','This experiment requires the saved odd-imaging/even-exposure layout.');
b=iceind.compile_kwave(s);
txIndex=s.ICEReport.num_imaging_angles+1; q=b.tx(txIndex);
assert(any(b.events.tx==txIndex),'iceind:TX','Exposure TX is not referenced.');
activeElements=find(q.apod~=0);
[~,order]=sort(b.geometry.positions_m(:,1));
assert(isequal(sort(order(2:2:end))',activeElements), ...
    'iceind:Partition','Saved exposure TX does not activate exactly the physical even elements.');
target=s.ICEConfig.exposure.foci_mm(1,:)*1e-3;
n=round(c.domain_m/c.dx_m); pml=round(c.pml_m/c.dx_m);
assert(all(abs(n*c.dx_m-c.domain_m)<1e-12) && abs(pml*c.dx_m-c.pml_m)<1e-12, ...
    'iceind:Grid','Grid spacing must divide domain and PML thickness.');
kg=kWaveGrid(n(1),c.dx_m,n(2),c.dx_m,n(3),c.dx_m);
sourceZ=-c.domain_m(3)/2+c.source_offset_m;
[~,sourceIz]=min(abs(kg.z_vec-sourceZ));
assert(abs(kg.z_vec(sourceIz)-sourceZ)<1e-12,'iceind:Grid','Source plane must align.');
positions=b.geometry.positions_m;
weights=zeros(n(1)*n(2),numel(activeElements),'single');
for j=1:numel(activeElements)
    e=activeElements(j);
    wx=max(0,min(kg.x_vec+c.dx_m/2,positions(e,1)+b.geometry.width_m/2)- ...
        max(kg.x_vec-c.dx_m/2,positions(e,1)-b.geometry.width_m/2))/c.dx_m;
    wy=max(0,min(kg.y_vec+c.dx_m/2,b.geometry.height_m/2)- ...
        max(kg.y_vec-c.dx_m/2,-b.geometry.height_m/2))/c.dx_m;
    a=wx(:)*wy(:)'; weights(:,j)=single(a(:));
end
area=b.geometry.width_m*b.geometry.height_m;
areaError=max(abs(sum(double(weights),1)*c.dx_m^2-area));
assert(areaError<1e-12,'iceind:Geometry','Rectangular source is clipped or incorrectly rasterized.');
source.p_mask=false(n); plane=any(weights~=0,2);
source.p_mask(:,:,sourceIz)=reshape(plane,n(1),n(2));
distance=sqrt((c.domain_m(1)/2+max(abs(positions(:,1))))^2+ ...
    (c.domain_m(2)/2+b.geometry.height_m/2)^2+ ...
    (c.domain_m(3)-c.source_offset_m)^2);
waveEnd=max(q.delay_s)+q.duration_s+2e-6;
kg.makeTime(b.sound_speed_m_s,c.cfl,waveEnd+distance/b.sound_speed_m_s+1e-6);
[wave,wm]=iceind.kw_waveform(q,kg.dt,waveEnd,c.source_amplitude_pa);
source.p=weights(plane,:)*wave(activeElements,:); source.p_mode='additive';
medium=struct('sound_speed',b.sound_speed_m_s,'density',c.density_kg_m3);
sensor.mask=false(n);
requested=target+[0 0 0;-.001 0 0;.001 0 0;0 0 -.005];
for j=1:size(requested,1)
    [~,ix]=min(abs(kg.x_vec-requested(j,1)));
    [~,iy]=min(abs(kg.y_vec-requested(j,2)));
    [~,iz]=min(abs(kg.z_vec-sourceZ-requested(j,3)));
    sensor.mask(ix,iy,iz)=true;
end
sensor.record={'p','p_max_all','p_min_all'};
[ix,iy,iz]=ind2sub(n,find(sensor.mask));
arrival=q.delay_s(activeElements)'+vecnorm(positions(activeElements,:)-target,2,2)/b.sound_speed_m_s;
fftLength=2^nextpow2(size(wave,2)*4);
spec=abs(fft(double(wave(activeElements(1),:)),fftLength)).^2;
freq=(0:fftLength/2)/(fftLength*kg.dt); spec=spec(1:numel(freq));
md=java.security.MessageDigest.getInstance('SHA-256');
fid=fopen(c.input_mat,'rb'); cleanup=onCleanup(@()fclose(fid)); md.update(fread(fid,Inf,'*uint8'));
sha=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
m=struct('input_mat',c.input_mat,'input_sha256',sha,'input_partition',s.ICEConfig.partition.layout, ...
    'num_elements',size(positions,1),'active_elements',activeElements,'tx_index',txIndex, ...
    'target_m',target,'element_area_m2',area,'area_error_m2',areaError, ...
    'source_z_offset_m',c.source_offset_m,'source_z_kgrid_m',sourceZ, ...
    'active_center_arrival_spread_s',range(arrival),'waveform',wm, ...
    'source_model','assumed_flat_rectangular_additive_pressure_no_lens', ...
    'elevation_focus_m_metadata_only',b.geometry.elevation_focus_m_metadata, ...
    'sound_speed_m_s',b.sound_speed_m_s,'source_pitch_m',.13e-3, ...
    'points_per_wavelength',b.sound_speed_m_s/q.frequency_hz/c.dx_m, ...
    'spectral_energy_above_spatial_nyquist_fraction',sum(spec(freq>b.sound_speed_m_s/(2*c.dx_m)))/sum(spec), ...
    'sensor_coordinates_m',[kg.x_vec(ix),kg.y_vec(iy),kg.z_vec(iz)-sourceZ], ...
    'source_geometry_provenance','existing_code_unverified','medium_provenance',c.provenance);
end
