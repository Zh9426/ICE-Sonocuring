function summary=run_curing_independent_readback_20261110()
% Independent read-only audit of freshly generated MAT objects; no driver calls.
% Expectations below are fixed to the task, not derived from ICEConfig/ICEReport.
root=fileparts(mfilename('fullpath'));
input=fullfile(root,'results','curing_export_2026-11-10');
out=fullfile(root,'results','curing_independent_readback_20261110');
assert(~isfolder(out),'iceind:IndependentAudit','Output already exists; retain evidence.');
mkdir(out);
started=tic;
names={'All64','Center48','Center32','Center16'};
masks={'FFFFFFFFFFFFFFFF','00FFFFFFFFFFFF00','0000FFFFFFFF0000','000000FFFF000000'};
ranks={1:64,9:56,17:48,25:40};
expectedWidth=[8.30 6.22 4.14 2.06];
checks=struct('variant',{},'check',{},'expected',{},'actual',{},'passed',{});
values=struct('variant',{},'active_elements',{},'actual_ranks',{},'aperture_mm',{}, ...
    'max_delay_us',{},'arrival_spread_us',{},'events',{},'transmits',{},'nominal_burst_us',{}, ...
    'minimum_interval_us',{},'nominal_on_per_active_element_us',{},'schedule_total_us',{},'source_mat',{});
elementRows=struct('variant',{},'logical_element',{},'physical_rank',{},'active_actual',{}, ...
    'x_mm',{},'y_mm',{},'z_mm',{},'delay_us',{},'target_arrival_us',{},'pulse_count',{}, ...
    'nominal_on_us',{},'minimum_start_interval_us',{});
eventRows=struct('variant',{},'event_index',{},'tx',{},'seqcontrol_indices',{}, ...
    'commands',{},'independent_start_us',{});
for k=1:4
    name=names{k}; file=fullfile(input,['ICE_CuringOnly_Exposure' masks{k} '_exposure_only.mat']);
    try
        S=load(file);
        req={'Trans','Resource','TW','TX','TPC','Event','SeqControl','ICEConfig','ICEReport'};
        add('required_fields',true,all(isfield(S,req)),all(isfield(S,req)));
        assert(all(isfield(S,req)),'Missing required MAT fields.');
        forbidden={'Receive','PData','Recon','Process','TGC','UI','Media','P'};
        found=intersect(fieldnames(S),forbidden);
        add('no_receive_objects','none',strjoin(found,','),isempty(found));
        tr=S.Trans; rs=S.Resource.Parameters;
        add('trans_units','wavelengths',tr.units,strcmp(tr.units,'wavelengths'));
        add('trans_type',0,tr.type,tr.type==0);
        add('element_count',64,tr.numelements,tr.numelements==64);
        add('reference_frequency_mhz',6.5,tr.frequency,abs(tr.frequency-6.5)<1e-12);
        add('sound_speed_m_s',1540,rs.speedOfSound,rs.speedOfSound==1540);
        scale=1540/6.5e6; % metres per wavelength, independent fixed task values.
        xyz=double(tr.ElementPos(:,1:3))*scale*1000;
        expectedXYZ=[((1:64)'-32.5)*0.13 zeros(64,2)];
        add('all_element_positions_mm',expectedXYZ,xyz,max(abs(xyz-expectedXYZ),[],'all')<1e-10);
        width=double(tr.elementWidth)*scale*1000;
        add('element_width_mm',0.11,width,abs(width-.11)<1e-12);
        add('connector_mapping',1:64,tr.ConnectorES(:)',isequal(tr.ConnectorES(:)',1:64));
        add('configured_channels',[128 128],[rs.numTransmit rs.numRcvChannels], ...
            isequal([rs.numTransmit rs.numRcvChannels],[128 128]));
        add('offline_runtime',[1 1 1],[rs.simulateMode rs.freezeOnStart rs.startEvent], ...
            isequal([rs.simulateMode rs.freezeOnStart rs.startEvent],[1 1 1]));
        add('resource_only_parameters',true,isequal(fieldnames(S.Resource),{'Parameters'}), ...
            isequal(fieldnames(S.Resource),{'Parameters'}));
        add('tx_count',1,numel(S.TX),numel(S.TX)==1);
        add('tw_count',1,numel(S.TW),numel(S.TW)==1);
        assert(numel(S.TX)==1 && numel(S.TW)==1,'Expected one TX and one TW.');
        tx=S.TX; tw=S.TW;
        waveformOK=isscalar(tx.waveform) && isfinite(tx.waveform) && tx.waveform==1;
        add('tx_waveform_reference',1,tx.waveform,waveformOK);
        add('tw_parametric','parametric',tw.type,strcmp(tw.type,'parametric'));
        add('tw_parameters',[6 .67 40 1],tw.Parameters, ...
            isequal(size(tw.Parameters),[1 4]) && max(abs(tw.Parameters-[6 .67 40 1]))<1e-12);
        apod=double(tx.Apod(:)); wanted=zeros(64,1); wanted(ranks{k})=1;
        add('actual_apodization',wanted,apod,isequal(apod,wanted));
        assert(numel(apod)==64,'Expected 64 apodization entries.');
        active=find(apod>0); actualRanks=active(:)';
        add('active_physical_ranks',ranks{k},actualRanks,isequal(actualRanks,ranks{k}));
        aperture=max(xyz(active,1))-min(xyz(active,1))+width;
        add('aperture_mm',expectedWidth(k),aperture,abs(aperture-expectedWidth(k))<1e-10);
        target=[0 0 20]; targetWls=target/(scale*1000);
        add('config_target_mm',target,S.ICEConfig.exposure.foci_mm, ...
            isequal(S.ICEConfig.exposure.foci_mm,target));
        add('tx_target_wls',targetWls,tx.FocalPt,max(abs(tx.FocalPt-targetWls))<1e-10);
        delayUs=double(tx.Delay(:))/6.5;
        add('finite_nonnegative_delays',true,all(isfinite(delayUs)&delayUs>=0),all(isfinite(delayUs)&delayUs>=0));
        distanceMm=sqrt(sum((expectedXYZ-target).^2,2));
        expectedDelay=zeros(64,1); expectedDelay(ranks{k})=(max(distanceMm(ranks{k}))-distanceMm(ranks{k}))/1.54;
        add('independent_geometric_delays_us',expectedDelay,delayUs,max(abs(delayUs-expectedDelay))<1e-11);
        d=delayUs(active); symmetry=max(abs(d-flipud(d)));
        add('delay_symmetry_us',0,symmetry,symmetry<1e-11);
        half=numel(active)/2;
        direction=abs(d(1))<1e-11 && abs(d(end))<1e-11 && ...
            all(diff(d(1:half))>=-1e-11) && all(diff(d(half+1:end))<=1e-11);
        add('outer_first_center_later',true,direction,direction);
        arrival=delayUs+sqrt(sum((xyz-target).^2,2))/1.54;
        spread=max(arrival(active))-min(arrival(active));
        add('target_arrival_spread_us',0,spread,spread<1e-10);
        % Inactive elements do not emit; an arrival time is not defined for them.
        arrival(apod<=0)=NaN;
        add('tpc_hv_omitted',true,~isfield(S.TPC,'hv'),~isfield(S.TPC,'hv'));
        add('tpc_xmit_duration_us',max(expectedDelay)+20/6,S.TPC.xmitDuration, ...
            abs(S.TPC.xmitDuration-max(expectedDelay)-20/6)<1e-11);
        ev=S.Event; sc=S.SeqControl; cmds={sc.command};
        add('event_count',363,numel(ev),numel(ev)==363);
        txids=[ev.tx]; ctrlOK=true;
        for e=1:numel(ev)
            ids=ev(e).seqControl;
            ctrlOK=ctrlOK && isnumeric(ids) && all(isfinite(ids)) && ...
                all(ids==fix(ids)) && all(ids>=0 & ids<=numel(sc));
        end
        txOK=all(isfinite(txids)) && all(txids==fix(txids)) && all(txids>=0 & txids<=numel(S.TX));
        add('event_tx_index_range',true,txOK,txOK);
        add('event_seqcontrol_index_range',true,ctrlOK,ctrlOK);
        add('event_no_rcv_recon_process',[0 0 0], ...
            [nnz([ev.rcv]) nnz([ev.recon]) nnz([ev.process])], ...
            ~any([ev.rcv]) && ~any([ev.recon]) && ~any([ev.process]));
        add('no_dma_return_jump',true,~any(ismember(cmds,{'transferToHost','returnToMatlab','jump'})), ...
            ~any(ismember(cmds,{'transferToHost','returnToMatlab','jump'})));
        allowed={'setTPCProfile','noop','timeToNextAcq','stop'};
        add('only_expected_commands',allowed,unique(cmds),all(ismember(cmds,allowed)));
        assert(ctrlOK && txOK,'Invalid references; downstream interpretation skipped.');
        clockUs=0; deadlineUs=0; starts=zeros(1,numel(ev)); stopped=false;
        perCount=zeros(64,1); perOn=zeros(64,1); perStarts=cell(64,1);
        txCount=0; stopEvents=[]; ttnaArgs=[]; noopArgs=[];
        for e=1:numel(ev)
            if ev(e).tx>0, clockUs=max(clockUs,deadlineUs); end
            starts(e)=clockUs;
            ids=ev(e).seqControl; ids=ids(ids>0);
            eventCmds={sc(ids).command};
            if ev(e).tx>0
                txCount=txCount+1;
                for a=active'
                    perCount(a)=perCount(a)+1; perOn(a)=perOn(a)+20/6;
                    perStarts{a}(end+1)=clockUs+delayUs(a);
                end
            end
            for id=ids
                command=sc(id).command; arg=double(sc(id).argument);
                switch command
                    case 'noop'
                        assert(isscalar(arg)&&isfinite(arg)&&arg==fix(arg)&&arg>=1&&arg<=2^25-1,'Invalid noop.');
                        noopArgs(end+1)=arg; clockUs=clockUs+arg*.2;
                    case 'timeToNextAcq'
                        assert(ev(e).tx>0&&isscalar(arg)&&isfinite(arg)&&arg>0,'Invalid TTNA.');
                        ttnaArgs(end+1)=arg; deadlineUs=clockUs+arg;
                    case 'setTPCProfile'
                        add(sprintf('profile_event_%d',e),[1 0 0],[arg ev(e).tx ev(e).rcv], ...
                            arg==1&&ev(e).tx==0&&ev(e).rcv==0&&strcmp(sc(id).condition,'immediate'));
                    case 'stop'
                        stopped=true; stopEvents(end+1)=e;
                end
            end
            eventRows(end+1)=struct('variant',name,'event_index',e,'tx',ev(e).tx, ...
                'seqcontrol_indices',mat2str(ev(e).seqControl),'commands',strjoin(eventCmds,'|'), ...
                'independent_start_us',starts(e));
            if stopped && e~=numel(ev), error('Stop before final event.'); end
        end
        add('finite_tx_count',300,txCount,txCount==300);
        add('final_stop_event',363,stopEvents,isequal(stopEvents,363));
        add('ttna_count',270,numel(ttnaArgs),numel(ttnaArgs)==270);
        add('all_ttna_arguments_us',1000,unique(ttnaArgs),all(ttnaArgs==1000));
        completion=ceil((max(expectedDelay)+20/6+5)*5);
        expectedNoops=[25000 repmat([completion 50000],1,30)];
        add('noop_order_and_ticks',expectedNoops,noopArgs,isequal(noopArgs,expectedNoops));
        txStarts=starts(txids>0); intervals=diff(txStarts);
        expectedIntervals=repmat([repmat(1000,1,9) completion*.2+10000],1,30);
        expectedIntervals=expectedIntervals(1:end-1);
        add('all_tx_start_intervals_us',expectedIntervals,intervals, ...
            numel(intervals)==299&&max(abs(intervals-expectedIntervals))<1e-8);
        add('config_groups',30,S.ICEConfig.sequence.num_groups,S.ICEConfig.sequence.num_groups==30);
        expectedTotal=5000+30*(9000+completion*.2+10000);
        add('total_schedule_us',expectedTotal,clockUs,abs(clockUs-expectedTotal)<1e-8);
        reportStarts=[S.ICEReport.timing.event_rows.scheduled_start_lower_bound_us];
        add('report_all_event_times',starts,reportStarts, ...
            numel(starts)==numel(reportStarts)&&max(abs(starts-reportStarts))<1e-8);
        expectedCount=zeros(64,1); expectedCount(ranks{k})=300;
        expectedOn=zeros(64,1); expectedOn(ranks{k})=1000;
        add('per_element_count',expectedCount,perCount,isequal(perCount,expectedCount));
        add('per_element_on_us',expectedOn,perOn,max(abs(perOn-expectedOn))<1e-8);
        perMin=nan(64,1);
        for a=1:64
            if numel(perStarts{a})>1, perMin(a)=min(diff(perStarts{a})); end
            elementRows(end+1)=struct('variant',name,'logical_element',a,'physical_rank',a, ...
                'active_actual',apod(a)>0,'x_mm',xyz(a,1),'y_mm',xyz(a,2),'z_mm',xyz(a,3), ...
                'delay_us',delayUs(a),'target_arrival_us',arrival(a),'pulse_count',perCount(a), ...
                'nominal_on_us',perOn(a),'minimum_start_interval_us',perMin(a));
        end
        add('all_active_element_min_interval_us',1000,perMin(active),all(abs(perMin(active)-1000)<1e-8));
        add('report_per_element_count',perCount,S.ICEReport.operating_envelope.per_element.exposure_pulses(:), ...
            isequal(perCount,S.ICEReport.operating_envelope.per_element.exposure_pulses(:)));
        add('report_per_element_on_us',perOn,S.ICEReport.operating_envelope.per_element.exposure_on_time_us(:), ...
            max(abs(perOn-S.ICEReport.operating_envelope.per_element.exposure_on_time_us(:)))<1e-8);
        values(end+1)=struct('variant',name,'active_elements',numel(active), ...
            'actual_ranks',mat2str(actualRanks),'aperture_mm',aperture,'max_delay_us',max(delayUs), ...
            'arrival_spread_us',spread,'events',numel(ev),'transmits',txCount, ...
            'nominal_burst_us',20/6,'minimum_interval_us',min(intervals), ...
            'nominal_on_per_active_element_us',max(perOn),'schedule_total_us',clockUs, ...
            'source_mat',file);
    catch err
        add('variant_exception','none',[err.identifier ': ' err.message],false);
        fprintf('INDEPENDENT_AUDIT %s failed: %s\n',name,err.message);
    end
end
writetable(struct2table(checks),fullfile(out,'checks.csv'),'Encoding','UTF-8');
if ~isempty(values), writetable(struct2table(values),fullfile(out,'actual_values.csv'),'Encoding','UTF-8'); end
if ~isempty(elementRows), writetable(struct2table(elementRows),fullfile(out,'elements.csv'),'Encoding','UTF-8'); end
if ~isempty(eventRows), writetable(struct2table(eventRows),fullfile(out,'events.csv'),'Encoding','UTF-8'); end
summary=struct('matlab',version,'generated_at',datestr(now,31),'runtime_s',toc(started), ...
    'input_dir',input,'output_dir',out,'variants_completed',numel(values), ...
    'checks',numel(checks),'passed',nnz([checks.passed]),'failed',nnz(~[checks.passed]), ...
    'all_passed',numel(values)==4&&all([checks.passed]), ...
    'limitations','Source-derived geometry and assumed nominal pulses; target_arrival_us is defined only for active emitters (inactive=NaN); no VSX, hardware, acoustic, thermal or curing validation.');
fid=fopen(fullfile(out,'summary.json'),'w','n','UTF-8'); assert(fid>=0); closeFile=onCleanup(@()fclose(fid));
fwrite(fid,unicode2native(jsonencode(summary,'PrettyPrint',true),'UTF-8'),'uint8');
disp(struct2table(values)); disp(summary);
assert(summary.all_passed,'iceind:IndependentAudit','Checks failed; evidence retained.');
    function add(label,expected,actual,passed)
        checks(end+1)=struct('variant',name,'check',label,'expected',fmt(expected), ...
            'actual',fmt(actual),'passed',logical(passed));
    end
end
function s=fmt(v)
if ischar(v),s=v;elseif isnumeric(v)||islogical(v),s=mat2str(v,12);else,s=jsonencode(v);end
end
