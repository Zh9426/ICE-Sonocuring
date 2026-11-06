function cases=widegrid_cases()
%WIDEGRID_CASES Same physical domain and PML, finer space/time discretization.
old=iceind.kwave_validation_cases(); c=old(3).config;
c.dx_m=52e-6;
c.output_dir=fullfile(fileparts(c.output_dir),'kwave_widegrid_2026-10-24');
root=fileparts(fileparts(mfilename('fullpath')));
budget=jsondecode(fileread(fullfile(root,'results','kwave_aperture_control_2026-10-23','analysis.json')));
kinds={'even32','full64_matched'};
cases=repmat(struct('tag','','kind','','config',c,'minimum_end_time_s',40e-6, ...
 'reference_budget_pa2_s_m2',budget.budget_even32_pa2_s_m2),1,2);
for j=1:2
 cases(j).kind=kinds{j}; cases(j).tag=['fine_' kinds{j}];
end
end
