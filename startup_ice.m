function root = startup_ice()
%STARTUP_ICE Add only project source folders; no persistent MATLAB path edits.
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'simulation'),fullfile(root,'config'), ...
    fullfile(root,'scripts'),fullfile(root,'adapters'));
end
