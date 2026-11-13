function manifest=curing_export_sparse_20261112()
% Export offline-only pure TX candidates; never loads VSX or hardware.
root=fileparts(mfilename('fullpath')); repo=fileparts(root); old=path; cleanup=onCleanup(@()path(old));
addpath(root,fullfile(repo,'verasonics','curing_mode'));
out=fullfile(root,'results','curing_sparse_2026-11-12','drivers');
assert(~isfolder(out),'iceind:NoOverwrite','Sparse driver output already exists.'); mkdir(out);
cases=iceind.curing_sparse_cases_20261112(); names={'Odd32','Even32'};
rows=repmat(struct('variant','','physical_ranks',[],'file','','sha256','', ...
    'width_mm',0,'center_mm',0,'arrival_spread_ns',0),1,2);
for k=1:2
    c=cases(k); cfg=icec.default_config(); cfg.partition.exposure_ranks=c.ranks;
    [seq,report,cfg]=SetUpICE_CuringOnly(cfg,out);
    saved=load(report.output_paths.mat); b=iceind.compile_kwave(saved);
    assert(numel(b.tx)==1 && isequal(find(b.tx.apod~=0),c.ranks));
    assert(isequal(sort(double(saved.ICEConfig.partition.exposure_ranks(:)')),c.ranks));
    x=b.geometry.positions_m(c.ranks,1); target=[0 0 .020];
    delay=reshape(b.tx.delay_s(c.ranks),[],1);
    arrival=delay+vecnorm(b.geometry.positions_m(c.ranks,:)-target,2,2)/b.sound_speed_m_s;
    assert(max(arrival)-min(arrival)<1e-12,'iceind:Sparse','Unequal model arrival times.');
    [~,name,ext]=fileparts(report.output_paths.mat);
    rows(k)=struct('variant',names{k},'physical_ranks',c.ranks,'file',[name ext], ...
        'sha256',iceind.curing_field_sha256(report.output_paths.mat), ...
        'width_mm',(max(x)-min(x)+b.geometry.width_m)*1e3, ...
        'center_mm',mean(x([1 end]))*1e3,'arrival_spread_ns',(max(arrival)-min(arrival))*1e9);
    assert(numel(seq.TX)==1 && all([seq.Event.rcv]==0));
end
manifest=struct('scope','offline hypothetical custom-rank pure-TX exports; not existing four drivers', ...
    'matlab',version,'target_mm',[0 0 20],'rows',rows);
iceind.curing_field_write_json(fullfile(out,'sparse_manifest.json'),manifest);
disp(struct2table(rows));
end
