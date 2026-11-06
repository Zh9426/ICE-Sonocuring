function cases=kwave_validation_cases()
%KWAVE_VALIDATION_CASES One-factor numerical controls, not hardware settings.
c=iceind.kwave_focus_config();
c.output_dir=fullfile(fileparts(c.output_dir),'kwave_singlepoint_validation_2026-10-22');
tags={'baseline65','pml65','wide65','long65','fine52'};
changes={'baseline extended recording window','PML thickness only', ...
 'transverse physical domain only','axial physical domain only','grid spacing only'};
cases=repmat(struct('tag','','config',c,'minimum_end_time_s',40e-6,'change',''),1,5);
for k=1:5
 cases(k).tag=tags{k}; cases(k).change=changes{k};
end
cases(2).config.pml_m=1.56e-3;
cases(3).config.domain_m=[15.6 10.4 31.2]*1e-3;
cases(4).config.domain_m=[10.4 5.2 41.6]*1e-3;
cases(5).config.dx_m=52e-6;
end
