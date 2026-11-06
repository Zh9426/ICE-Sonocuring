function verify_kwave_singlepoint_validation()
%VERIFY_KWAVE_SINGLEPOINT_VALIDATION Save actual regression/analyzer evidence.
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use MATLAB R2024b.');
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior)); addpath(root);
out=fullfile(root,'results','kwave_singlepoint_validation_2026-10-22');
if ~isfolder(out), mkdir(out); end
r=runtests(fullfile(root,'tests'));
writetable(table({r.Name}',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]', ...
 'VariableNames',{'Test','Passed','Failed','Incomplete','Duration_s'}),fullfile(out,'test_results.csv'));
files={'run_kwave_singlepoint_validation.m','verify_kwave_singlepoint_validation.m', ...
 '+iceind/kwave_validation_cases.m','+iceind/rms_to_qp.m','+iceind/pressure_exposure_metrics.m', ...
 'tests/test_kwave_singlepoint_validation.m'};
analysis=struct('file',{},'messages',{});
for k=1:numel(files)
 analysis(k)=struct('file',files{k},'messages',checkcode(fullfile(root,files{k}),'-id'));
end
fid=fopen(fullfile(out,'code_analysis.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(analysis,'PrettyPrint',true),'char');
assertSuccess(r);
assert(all(arrayfun(@(a)isempty(a.messages),analysis)),'iceind:Analysis','Inspect Code Analyzer messages.');
end
