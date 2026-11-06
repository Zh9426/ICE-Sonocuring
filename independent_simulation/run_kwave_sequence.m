function reports=run_kwave_sequence(sequence,txIndices,dx)
%RUN_KWAVE_SEQUENCE Execute unique acoustic TX jobs from Event manifest.
% run_kwave_sequence('original','all',64e-6) runs all 15 imaging TXs.
% run_kwave_sequence('dual',16,64e-6) runs only the exposure TX.
% Repeated events refer to the same field only for static linear media.
if nargin<1,sequence='dual';end
if nargin<2,txIndices=16;end
if nargin<3,dx=64e-6;end
root=fileparts(mfilename('fullpath'));
run_kwave_import();
d=load(fullfile(root,'results','kwave',[sequence '_compiled.mat']),'b');
available=unique(d.b.events.tx(d.b.events.tx>0))';
if ischar(txIndices) && strcmp(txIndices,'all'),txIndices=available;end
assert(isnumeric(txIndices) && all(ismember(txIndices,available)),'iceind:TX','Invalid TX selection.');
txIndices=unique(txIndices,'stable'); reports=struct([]);
for k=1:numel(txIndices)
    current=run_kwave_field(sequence,txIndices(k),dx);
    if k==1
        reports=current;
    else
        reports(k)=current;
    end
end
% Audit event-to-result mapping, explicitly identifying unexecuted events.
map=d.b.events;
map.acoustic_status=repmat({'not_a_transmit'},height(map),1);
map.result_file=repmat({''},height(map),1);
starts=map.start_lower_bound_s(map.tx>0);
minGap=min(diff(starts));
for k=1:height(map)
    if map.tx(k)>0
        if ismember(map.tx(k),txIndices)
            map.acoustic_status{k}='unique_tx_field_computed';
            map.result_file{k}=sprintf('%s_tx%d_dx%.1fum.mat',sequence,map.tx(k),dx*1e6);
        else
            map.acoustic_status{k}='not_simulated';
        end
    end
end
% This dispatch does not concatenate p(t) or claim a full hardware timeline.
maxWindow=max([reports.Nt].*[reports.dt_s]);
assert(isempty(minGap) || minGap>maxWindow,'iceind:Overlap', ...
    'Events may acoustically overlap; independent-shot reuse is not justified.');
writetable(map,fullfile(root,'results','kwave',[sequence '_execution_map.csv']));
end
