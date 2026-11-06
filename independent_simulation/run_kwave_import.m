function manifests=run_kwave_import()
%RUN_KWAVE_IMPORT Read saved original and dual-mode SetUp structures.
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
out=fullfile(root,'results','kwave'); if ~isfolder(out),mkdir(out);end
files={fullfile(repo,'VantageNXT-2.3.2-p2','MatFiles','SetUpP9_4TSICE_FlashAngles.mat'), ...
    fullfile(repo,'results','verasonics_dual_mode','ICE_ImagingCuring_interleaved.mat')};
names={'original','dual'};
for k=1:2
    s=load(files{k}); b=iceind.compile_kwave(s);
    b.input_path=files{k};
    md=java.security.MessageDigest.getInstance('SHA-256');
    fid=fopen(files{k},'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    md.update(bytes); b.sha256=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
    writetable(b.events,fullfile(out,[names{k} '_events.csv']));
    save(fullfile(out,[names{k} '_compiled.mat']),'b');
    summary=rmfield(b,'events'); summary.event_count=height(b.events);
    summary.transmit_count=sum(b.events.tx>0);
    summary.unique_tx=unique(b.events.tx(b.events.tx>0))';
    fid=fopen(fullfile(out,[names{k} '_manifest.json']),'w');
    fwrite(fid,jsonencode(summary,'PrettyPrint',true),'char'); fclose(fid);
    manifests(k)=summary;
end
end
