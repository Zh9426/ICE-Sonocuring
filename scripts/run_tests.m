function results = run_tests()
%RUN_TESTS Run all project tests and write a machine-readable local summary.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
out=fullfile(root,'results','validation');if ~exist(out,'dir'),mkdir(out);end
results=runtests(fullfile(root,'tests'));
summary=table({results.Name}',[results.Passed]',[results.Failed]',[results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Test','Passed','Failed','Incomplete','Duration_s'});
writetable(summary,fullfile(out,'test_results.csv'));
disp(summary);assertSuccess(results);
end
