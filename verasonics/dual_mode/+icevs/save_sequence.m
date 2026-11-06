function paths = save_sequence(seq,report,cfg,outdir)
%SAVE_SEQUENCE Save inspectable artifacts; does not run the saved sequence.
if ~isfolder(outdir), mkdir(outdir); end
if strcmp(cfg.probe.type,'linear')
    switch cfg.partition.layout
        case {'full64_imaging_selected_exposure','exposure_only_selected'}
            % Exact physical-rank mask encoded as 16 hex digits; distinct
            % equal-size subsets cannot overwrite one another by count alone.
            bits=double(ismember(1:64,cfg.partition.exposure_ranks));
            maskKey=reshape(dec2hex(sum(reshape(bits,4,[]).*[8;4;2;1],1))',1,[]);
            prefix=['ICE_Linear64FullImage_Exposure' maskKey '_'];
            if strcmp(cfg.partition.layout,'exposure_only_selected')
                prefix=['ICE_CuringOnly_Exposure' maskKey '_'];
            end
        case 'full64_imaging_control', prefix='ICE_Linear64FullControl_';
        case 'odd_imaging_even_exposure', prefix='ICE_Linear64OddEven_';
        case 'even_imaging_odd_exposure', prefix='ICE_Linear64EvenOdd_';
        otherwise, prefix='ICE_Linear64Partition_';
    end
else
    prefix='ICE_SyntheticMatrixPartition_';
end
if isfield(report,'original_sector_restored') && report.original_sector_restored
    prefix=['OriginalSector_' prefix];
end
stem = [prefix cfg.mode];
paths = struct('mat',fullfile(outdir,[stem '.mat']), ...
    'json',fullfile(outdir,[stem '_report.json']), ...
    'events_csv',fullfile(outdir,[stem '_events.csv']), ...
    'elements_csv',fullfile(outdir,[stem '_elements.csv']));
payload=seq; payload.ICEConfig=cfg; payload.ICEReport=report;
save(paths.mat,'-struct','payload');
fid=fopen(paths.json,'w','n','UTF-8');
if fid<0, error('icevs:Export','Cannot open report file: %s',paths.json); end
closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(struct('config',cfg,'report',report),'PrettyPrint',true),'char');
events=struct2table(report.timing.event_rows);
events.tx=[seq.Event.tx]'; events.rcv=[seq.Event.rcv]';
events.recon=[seq.Event.recon]'; events.process=[seq.Event.process]';
events.commands=cell(height(events),1);
for k=1:height(events)
    indices=seq.Event(k).seqControl;
    indices=indices(indices>0);
    events.commands{k}=strjoin({seq.SeqControl(indices).command},'|');
end
writetable(events,paths.events_csv,'Encoding','UTF-8');
xyz=seq.Trans.ElementPos(:,1:3)*report.wavelength_mm;
part=report.partition;
elements=table((1:seq.Trans.numelements)',part.column,part.row,xyz(:,1),xyz(:,2),xyz(:,3), ...
    seq.Trans.ConnectorES,part.imaging_mask,part.exposure_mask, ...
    repmat({cfg.probe.connector_provenance},seq.Trans.numelements,1), ...
    'VariableNames',{'logical_element','column','row','x_mm','y_mm','z_mm', ...
    'connector_signal_assumed','imaging','exposure','mapping_provenance'});
writetable(elements,paths.elements_csv,'Encoding','UTF-8');
end
