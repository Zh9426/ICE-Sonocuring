function [kg,medium,source,m,wave]=prepare_aperture_control(c,kind)
%PREPARE_APERTURE_CONTROL Offline mask change; saved hardware TX is untouched.
assert(ismember(kind,{'even32','full64_matched'}),'iceind:Aperture','Unknown control.');
[kg,medium,source,~,m,wave]=iceind.prepare_kwave_focus(c);
reference=m.element_area_m2*kg.dt*sum(double(wave(m.active_elements,:)).^2,'all');
scale=1; actual=reference;
if strcmp(kind,'full64_matched')
 saved=load(c.input_mat); b=iceind.compile_kwave(saved); q=b.tx(m.tx_index);
 pos=b.geometry.positions_m; distance=vecnorm(pos-m.target_m,2,2);
 q.delay_s=((max(distance)-distance)/b.sound_speed_m_s)';
 q.apod=ones(1,size(pos,1)); active=1:size(pos,1);
 waveEnd=max(q.delay_s)+q.duration_s+2e-6;
 [wave,wm]=iceind.kw_waveform(q,kg.dt,waveEnd,c.source_amplitude_pa);
 unscaled=m.element_area_m2*kg.dt*sum(double(wave).^2,'all');
 scale=sqrt(reference/unscaled); wave=wave*single(scale);
 actual=m.element_area_m2*kg.dt*sum(double(wave).^2,'all');
 n=[kg.Nx kg.Ny kg.Nz]; weights=zeros(n(1)*n(2),numel(active),'single');
 for j=active
  wx=max(0,min(kg.x_vec+c.dx_m/2,pos(j,1)+b.geometry.width_m/2)- ...
   max(kg.x_vec-c.dx_m/2,pos(j,1)-b.geometry.width_m/2))/c.dx_m;
  wy=max(0,min(kg.y_vec+c.dx_m/2,b.geometry.height_m/2)- ...
   max(kg.y_vec-c.dx_m/2,-b.geometry.height_m/2))/c.dx_m;
  area=wx(:)*wy(:)'; weights(:,j)=single(area(:));
 end
 areaError=max(abs(sum(double(weights),1)*c.dx_m^2-m.element_area_m2));
 assert(areaError<1e-12,'iceind:Geometry','Source rectangle clipped.');
 [~,iz]=min(abs(kg.z_vec-m.source_z_kgrid_m)); plane=any(weights~=0,2);
 source.p_mask=false(n); source.p_mask(:,:,iz)=reshape(plane,n(1),n(2));
 source.p=weights(plane,:)*wave; source.p_mode='additive';
 m.active_elements=active; m.area_error_m2=areaError;
 m.active_center_arrival_spread_s=range(q.delay_s'+distance/b.sound_speed_m_s);
 wm.assumed_reference_source_pa=c.source_amplitude_pa*scale;
 m.waveform=wm; m.saved_tx_used_as_template_only=true;
 fftLength=2^nextpow2(size(wave,2)*4);
 spec=abs(fft(double(wave(1,:)),fftLength)).^2;
 freq=(0:fftLength/2)/(fftLength*kg.dt); spec=spec(1:numel(freq));
 m.spectral_energy_above_spatial_nyquist_fraction=sum(spec(freq>b.sound_speed_m_s/(2*c.dx_m)))/sum(spec);
else
 saved=load(c.input_mat); b=iceind.compile_kwave(saved); pos=b.geometry.positions_m;
 q=b.tx(m.tx_index);
 m.saved_tx_used_as_template_only=false;
end
assert(abs(actual/reference-1)<1e-6,'iceind:Budget','Source proxy budgets differ.');
activeX=sort(pos(m.active_elements,1));
m.aperture_control=struct('kind',kind,'reference_budget_pa2_s_m2',reference, ...
 'actual_budget_pa2_s_m2',actual,'signal_scale',scale, ...
 'active_pitch_m',median(diff(activeX)),'active_center_x_m',mean(activeX), ...
 'outer_aperture_x_m',range(activeX)+b.geometry.width_m,'delay_s',q.delay_s, ...
 'budget_definition','element_area*dt*sum_e,t(signal_e(t)^2), Pa^2 s m^2; not power or energy.', ...
 'provenance','synthetic_offline_aperture_control_not_hardware_TX');
end
