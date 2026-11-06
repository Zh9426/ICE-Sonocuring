function verify_widegrid()
%VERIFY_WIDEGRID CPU suite and static checks, saved to this run only.
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior)); addpath(root);
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use R2024b.');
cases=iceind.widegrid_cases(); out=cases(1).config.output_dir;
if ~isfolder(out), mkdir(out); end
r=runtests(fullfile(root,'tests'));
writetable(table({r.Name}',[r.Passed]',[r.Failed]',[r.Incomplete]', ...
 'VariableNames',{'Test','Passed','Failed','Incomplete'}),fullfile(out,'test_results.csv'));
files={'+iceind/widegrid_cases.m','+iceind/prepare_widegrid.m', ...
 '+iceind/widegrid_probe_matches.m', ...
 'verify_widegrid.m','run_kwave_widegrid.m','tests/test_widegrid.m'};
a=struct('file',{},'messages',{});
for j=1:numel(files), a(j)=struct('file',files{j},'messages',checkcode(fullfile(root,files{j}),'-id')); end
fid=fopen(fullfile(out,'code_analysis.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(a,'PrettyPrint',true),'char'); assertSuccess(r);
assert(all(arrayfun(@(x)isempty(x.messages),a)),'iceind:Analysis','Inspect analyzer messages.');
end
