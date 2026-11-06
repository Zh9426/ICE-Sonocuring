function verify_kwave_offaxis_diagnostic()
%VERIFY_KWAVE_OFFAXIS_DIAGNOSTIC Preserve new evidence separately from old runs.
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use MATLAB R2024b.');
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior)); addpath(root);
out=fullfile(root,'results','kwave_offaxis_diagnostic_2026-10-22');
if ~isfolder(out), mkdir(out); end
r=runtests(fullfile(root,'tests'));
writetable(table({r.Name}',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]', ...
 'VariableNames',{'Test','Passed','Failed','Incomplete','Duration_s'}),fullfile(out,'test_results.csv'));
files={'run_kwave_offaxis_diagnostic.m','verify_kwave_offaxis_diagnostic.m', ...
 '+iceind/kwave_offaxis_cases.m','+iceind/offaxis_sensor.m','+iceind/trace_integral_audit.m', ...
 'tests/test_kwave_offaxis_diagnostic.m'};
analysis=struct('file',{},'messages',{});
for k=1:numel(files)
 analysis(k)=struct('file',files{k},'messages',checkcode(fullfile(root,files{k}),'-id'));
end
fid=fopen(fullfile(out,'code_analysis.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(analysis,'PrettyPrint',true),'char'); assertSuccess(r);
assert(all(arrayfun(@(a)isempty(a.messages),analysis)),'iceind:Analysis','Inspect Code Analyzer messages.');
end
