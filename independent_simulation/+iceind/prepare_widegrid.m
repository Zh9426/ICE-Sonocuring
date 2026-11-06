function [kg,medium,source,m,wave]=prepare_widegrid(item)
%PREPARE_WIDEGRID Match final discrete element-signal budget across grids.
[kg,medium,source,m,wave]=iceind.prepare_aperture_control(item.config,item.kind);
before=m.element_area_m2*kg.dt*sum(double(wave).^2,'all');
gain=sqrt(item.reference_budget_pa2_s_m2/before);
wave=wave*single(gain); source.p=source.p*single(gain);
actual=m.element_area_m2*kg.dt*sum(double(wave).^2,'all');
assert(abs(actual/item.reference_budget_pa2_s_m2-1)<1e-6,'iceind:Budget','Cross-grid source budget mismatch.');
m.aperture_control.budget_stage='Aperture-adapter values before cross-grid scaling; final budget is widegrid_budget.actual_budget_pa2_s_m2';
m.widegrid_budget=struct('reference_budget_pa2_s_m2',item.reference_budget_pa2_s_m2, ...
 'before_crossgrid_scaling_pa2_s_m2',before,'actual_budget_pa2_s_m2',actual, ...
 'signal_scale_across_grids',gain,'definition','element_area*dt*sum_e,t(signal_e(t)^2); not acoustic power or energy');
m.waveform.assumed_reference_source_pa=m.waveform.assumed_reference_source_pa*gain;
kg.setTime(max(kg.Nt,ceil(item.minimum_end_time_s/kg.dt)+1),kg.dt);
end
