function test_steered_focus_metadata_20261119()
% Rejected metadata fail before k-Wave grids/source allocation; no propagation.
root=fileparts(mfilename('fullpath')); addpath(root);
base=load(fullfile(root,'results','curing_export_2026-11-10', ...
    'ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat'));
cases=iceind.curing_field_cases(true);
c=cases(find(strcmp({cases.variant},'All64') & abs([cases.dx_m]-52e-6)<1e-12,1));
driver=[tempname(root) '.mat']; cleanup=onCleanup(@()local_remove(driver)); %#ok<NASGU>
for k=1:5
    s=iceind.steered_focus_input_20261119(base,20);
    switch k
        case 1, s.ICEConfig.exposure.foci_mm=[0 0 20];
        case 2, s.synthetic_target_m=[0 0 .02];
        case 3, s.synthetic_angle_deg=15;
        case 4, s=rmfield(s,'synthetic_angle_deg');
        case 5, s.synthetic_focus_depth_mm=20;
    end
    save(driver,'-struct','s');
    rejected=false;
    try
        iceind.curing_bli_prepare(c,driver);
    catch err
        assert(strcmp(err.identifier,'iceind:CuringBLITarget'), ...
            'Unexpected failure instead of early target validation: %s',err.message);
        rejected=true;
    end
    assert(rejected,'Mismatched synthetic target metadata was accepted.');
end
disp('PASS: 5 inconsistent steering metadata cases rejected before allocation.');
end

function local_remove(filename)
if isfile(filename), delete(filename); end
end
