function results=curing_field_run_tests()
%CURING_FIELD_RUN_TESTS Unit tests that require no full propagation.
root=fileparts(mfilename('fullpath'));
old=path; cleanup=onCleanup(@()path(old));
addpath(root);
td=fullfile(root,'tests','curing_field_2026-11-10');
addpath(td);
kw=fullfile(root,'dependencies','k-wave-1.4.1','k-Wave');
if ~isfolder(kw), kw=fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'); end
addpath(kw);
out=fullfile(root,'results','curing_field_2026-11-10','tests');
if ~isfolder(out), mkdir(out); end
files=dir(fullfile(td,'curing_field_test_*.m'));
assert(~isempty(files),'iceind:CuringField','No curing_field test files found.');
results=runtests(fullfile(td,{files.name}));
t=table({results.Name}',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Test','Passed','Failed','Incomplete','Duration_s'});
writetable(t,fullfile(out,'test_results.csv'),'Encoding','UTF-8');
disp(t);
assertSuccess(results);
end
