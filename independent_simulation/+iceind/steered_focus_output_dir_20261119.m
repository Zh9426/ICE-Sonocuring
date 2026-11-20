function out=steered_focus_output_dir_20261119(root,runTag)
%STEERED_FOCUS_OUTPUT_DIR_20261119 Select an offline run directory; no mkdir.
% Empty tags preserve the original output layout and NoOverwrite behavior.
if nargin<2, runTag=''; end
if isstring(runTag) && isscalar(runTag) && ~ismissing(runTag)
    runTag=char(runTag);
end
assert(ischar(runTag) && (isempty(runTag) || isrow(runTag)), ...
    'iceind:SteeredFocusRunTag','Run tag must be empty or a scalar text value.');
assert(isempty(runTag) || (numel(runTag)<=64 && ...
    ~isempty(regexp(runTag(1),'[A-Za-z0-9]','once')) && ...
    isempty(regexp(runTag,'[^A-Za-z0-9_-]','once'))), ...
    'iceind:SteeredFocusRunTag', ...
    'Run tag must contain 1-64 ASCII letters, digits, underscores or hyphens, starting with a letter or digit.');
out=fullfile(root,'results','steered_focus_2026-11-19','common_y6p24');
if ~isempty(runTag), out=fullfile(out,runTag); end
end
