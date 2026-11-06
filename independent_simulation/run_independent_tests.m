function results=run_independent_tests()
%RUN_INDEPENDENT_TESTS Test only the independent simulation folder.
root=fileparts(mfilename('fullpath'));
old=path; cleanup=onCleanup(@()path(old));
addpath(root);
out=fullfile(root,'results'); if ~isfolder(out), mkdir(out); end
results=runtests(fullfile(root,'tests'));
t=table({results.Name}',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Test','Passed','Failed','Incomplete','Duration_s'});
writetable(t,fullfile(out,'test_results.csv'));
disp(t); assertSuccess(results);
end
