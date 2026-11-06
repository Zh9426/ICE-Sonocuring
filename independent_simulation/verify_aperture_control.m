function verify_aperture_control()
%VERIFY_APERTURE_CONTROL CPU tests only; no hardware or GPU solve.
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior)); addpath(root);
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use R2024b.');
out=fullfile(root,'results','kwave_aperture_control_2026-10-23');
if ~isfolder(out), mkdir(out); end
r=runtests(fullfile(root,'tests'));
writetable(table({r.Name}',[r.Passed]',[r.Failed]',[r.Incomplete]', ...
 'VariableNames',{'Test','Passed','Failed','Incomplete'}),fullfile(out,'test_results.csv'));
files={'+iceind/prepare_aperture_control.m','verify_aperture_control.m', ...
 'run_kwave_aperture_control.m','tests/test_aperture_control.m'};
a=struct('file',{},'messages',{});
for j=1:numel(files), a(j)=struct('file',files{j},'messages',checkcode(fullfile(root,files{j}),'-id')); end
fid=fopen(fullfile(out,'code_analysis.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(a,'PrettyPrint',true),'char'); assertSuccess(r);
assert(all(arrayfun(@(x)isempty(x.messages),a)),'iceind:Analysis','Inspect analyzer messages.');
end
