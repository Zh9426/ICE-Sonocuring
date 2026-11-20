function [seq,report,cfg]=all64_35v_candidate()
%ALL64_35V_CANDIDATE Offline comparison candidate; NOT hardware qualified.
% 35 V is the existing software cap, not a verified transducer rating.
% Other settings retain assumed defaults because their safe maxima are unknown.
cfg=icec.default_config();
cfg.partition.exposure_ranks=1:64;
cfg.exposure.foci_mm=[0 0 20];
cfg.exposure.tpc_profile=1;
cfg.exposure.voltage_v=35;
cfg.exposure.provenance='offline_35V_existing_software_cap_other_settings_assumed';
[seq,report]=icec.build(cfg);
report.limitations{end+1}=['35 V is an existing software cap, not a probe rating; ' ...
    'this offline candidate is not maximum-safe power or hardware authorized.'];
end
