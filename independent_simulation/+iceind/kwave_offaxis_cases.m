function cases=kwave_offaxis_cases()
%KWAVE_OFFAXIS_CASES Independent one-factor controls relative to old wide65.
old=iceind.kwave_validation_cases(); c=old(3).config;
c.output_dir=fullfile(fileparts(c.output_dir),'kwave_offaxis_diagnostic_2026-10-22');
cases=repmat(struct('tag','','config',c,'minimum_end_time_s',40e-6,'change',''),1,2);
cases(1).tag='wide_pml20'; cases(1).change='PML thickness only relative to wide65';
cases(1).config.pml_m=1.30e-3;
cases(2).tag='wider_x256'; cases(2).change='X physical domain only relative to wide65';
cases(2).config.domain_m(1)=16.64e-3;
end
