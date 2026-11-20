function test_steered_focus_output_dir_20261119()
% Run directory selection only: no propagation, filesystem writes or hardware.
root=tempname;
baseline=fullfile(root,'results','steered_focus_2026-11-19','common_y6p24');
assert(strcmp(iceind.steered_focus_output_dir_20261119(root),baseline));
assert(strcmp(iceind.steered_focus_output_dir_20261119(root,''),baseline));
assert(strcmp(iceind.steered_focus_output_dir_20261119(root,""),baseline));
valid={'rerun_20261120','A','0-run',repmat('a',1,64)};
for k=1:numel(valid)
    assert(strcmp(iceind.steered_focus_output_dir_20261119(root,valid{k}), ...
        fullfile(baseline,valid{k})));
end
assert(strcmp(iceind.steered_focus_output_dir_20261119(root,"string_tag"), ...
    fullfile(baseline,'string_tag')));
invalid={'..','../escape','..\escape','a/b','a\b','a:b','a b', ...
    ' tag','tag ','''','"','a''b','a"b','_tag','-tag', ...
    repmat('a',1,65),sprintf('a\nb'),sprintf('a\n'),sprintf('a\tb'), ...
    '中文',[],1,{'tag'},["one" "two"],['ab';'cd']};
for k=1:numel(invalid)
    caught=false;
    try
        iceind.steered_focus_output_dir_20261119(root,invalid{k});
    catch err
        assert(strcmp(err.identifier,'iceind:SteeredFocusRunTag'), ...
            'Unexpected error identifier: %s',err.identifier);
        caught=true;
    end
    assert(caught,'Invalid run tag case %d was accepted.',k);
end
assert(~isfolder(root),'Directory selection must not create directories.');
disp('PASS: default and isolated run directories, strict run tag rejection, no mkdir.');
end
