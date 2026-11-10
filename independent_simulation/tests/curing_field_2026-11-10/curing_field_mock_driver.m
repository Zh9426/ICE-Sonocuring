function s=curing_field_mock_driver(ranks)
%CURING_FIELD_MOCK_DRIVER Minimal saved-sequence struct for unit tests only.
% Mirrors the fields iceind.compile_kwave consumes; it is NOT a vendor export.
c0=1540; f=6.5; lambda_mm=c0/(f*1e6)*1e3; scale=f/(c0/1000);
pos_mm=((-(64-1)/2):((64-1)/2))'*0.13;
apod=zeros(1,64); apod(ranks)=1;
target_wl=[0 0 20/lambda_mm];
d=vecnorm([pos_mm*scale zeros(64,2)]-target_wl,2,2);
delay=zeros(1,64); delay(ranks)=(max(d(ranks))-d(ranks))';
s.Trans=struct('name','mock64','numelements',64,'frequency',f, ...
    'type',0,'units','wavelengths', ...
    'elementWidth',0.11*scale,'elevationApertureMm',2.02, ...
    'elevationFocusMm',30, ...
    'maxHighVoltage',35,'spacingMm',0.13, ...
    'spacing',0.13*scale);
s.Trans.Bandwidth=[4 9];
s.Trans.ElementPos=[pos_mm*scale zeros(64,4)];
s.Trans.ConnectorES=(1:64)';
s.Resource.Parameters.speedOfSound=c0;
s.TW=struct('type','parametric');
s.TW.Parameters=[6 .67 40 1];
s.TX=struct('waveform',1,'focus',norm(target_wl));
s.TX.Origin=[0 0 0];
s.TX.Steer=[0 0];
s.TX.FocalPt=target_wl;
s.TX.Apod=apod;
s.TX.Delay=delay;
s.TPC=struct('maxHighVoltage',35,'xmitDuration',20/6+max(delay)/f);
s.SeqControl=struct('command','stop','argument',[],'condition',[]);
s.Event=struct('info','mock exposure','tx',1,'rcv',0,'recon',0,'process',0,'seqControl',1);
part=struct('layout','exposure_only_selected');
part.exposure_ranks=ranks;
expcfg=struct();
expcfg.foci_mm=[0 0 20];
s.ICEConfig=struct('partition',part,'exposure',expcfg);
s.ICEReport=struct('mode','exposure_only','num_exposure_foci',1);
end
