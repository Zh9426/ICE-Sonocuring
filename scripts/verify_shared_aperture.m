function summary=verify_shared_aperture()
%VERIFY_SHARED_APERTURE Tests and offline candidates; never calls VSX/hardware.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'verasonics','dual_mode'));
out=fullfile(root,'results','shared_aperture_2026-11-01');
if ~isfolder(out), mkdir(out); end
files=dir(fullfile(root,'tests','test_verasonics_*.m'));
testPaths=arrayfun(@(v)fullfile(v.folder,v.name),files,'UniformOutput',false);
assert(~isempty(testPaths),'No Verasonics regression tests found.');
testLog=evalc('testResults=runtests(testPaths);');
writeText(fullfile(out,'tests.log'),testLog);
writetable(table(testResults),fullfile(out,'test_results.csv'));
fprintf('TESTS total=%d passed=%d failed=%d incomplete=%d\n',numel(testResults), ...
    sum([testResults.Passed]),sum([testResults.Failed]),sum([testResults.Incomplete]));
assertSuccess(testResults);

% Current default three modes; old original-sector and odd/even exports retained.
generationLog=evalc('verify_verasonics_dual_mode();');
writeText(fullfile(out,'generation.log'),generationLog);
subsets={4:4:64,2:2:64,1:64};
rows=struct('candidate',{},'imaging_elements',{},'exposure_elements',{}, ...
    'shared_elements',{},'max_element_on_time_us',{},'total_element_on_time_us',{}, ...
    'acoustic_power_status',{},'hardware_qualified',{});
for k=1:numel(subsets)
    c=icevs.default_config(root); c.partition.exposure_ranks=subsets{k};
    [s,r]=SetUpICE_ImagingCuring(c,fullfile(out,'candidates'));
    original=load(c.baseline_mat,'Receive','PData','TX');
    assert(isequaln(s.Receive,original.Receive));
    assert(isequaln(s.PData,original.PData));
    for angle=1:numel(c.imaging.angles_deg)
        assert(max(abs(s.TX(angle).Delay-original.TX(angle).Delay))<1e-11);
        assert(isequal(s.TX(angle).Apod,original.TX(angle).Apod));
    end
    e=r.operating_envelope;
    rows(k)=struct('candidate',sprintf('full64_image_%d_exposure',numel(subsets{k})), ...
        'imaging_elements',r.partition.imaging_count,'exposure_elements',r.partition.exposure_count, ...
        'shared_elements',r.partition.shared_count, ...
        'max_element_on_time_us',e.max_element_total_on_time_us, ...
        'total_element_on_time_us',e.total_element_on_time_us, ...
        'acoustic_power_status',e.acoustic_power_status,'hardware_qualified',e.hardware_qualified);
end
summary=struct2table(rows);
writetable(summary,fullfile(out,'candidate_summary.csv'),'Encoding','UTF-8');
codeFiles=[dir(fullfile(root,'verasonics','dual_mode','**','*.m')); ...
    files; dir(fullfile(root,'scripts','verify_verasonics_dual_mode.m')); ...
    dir(fullfile(root,'scripts','verify_shared_aperture.m'))];
analysis=struct('file',{},'messages',{});
for k=1:numel(codeFiles)
    file=fullfile(codeFiles(k).folder,codeFiles(k).name);
    analysis(k)=struct('file',file,'messages',checkcode(file,'-id'));
end
writeText(fullfile(out,'code_analysis.json'), ...
    jsonencode(struct('matlab_version',version,'files',analysis),'PrettyPrint',true));
fprintf('ANALYZER files=%d messages=%d\n',numel(analysis), ...
    sum(arrayfun(@(v)numel(v.messages),analysis)));
disp(summary);
fprintf('All candidate imaging TX, 450 Receive entries and PData match the original MAT.\n');
end
function writeText(file,content)
fid=fopen(file,'w','n','UTF-8');
if fid<0, error('icevs:Export','Cannot write %s.',file); end
cleanup=onCleanup(@()fclose(fid));
fwrite(fid,unicode2native(content,'UTF-8'),'uint8');
end
