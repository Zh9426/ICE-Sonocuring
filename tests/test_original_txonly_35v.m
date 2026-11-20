function tests=test_original_txonly_35v
tests=functiontests(localfunctions);
end
function testConstructedSequence(t)
root=fileparts(fileparts(mfilename('fullpath')));
p=fullfile(root,'verasonics','curing_mode','SetUpP9_4TSICE_TXOnly_20mm_35V_offline.m');
verifyTrue(t,isfile(p));
evalin('base',sprintf('run(''%s'')',strrep(p,'''','''''')));
s=evalin('base','struct(''Resource'',Resource,''Trans'',Trans,''TW'',TW,''TX'',TX,''TPC'',TPC,''Event'',Event,''SeqControl'',SeqControl)');
verifyEqual(t,s.Resource.Parameters.simulateMode,1);
verifyEqual(t,s.Trans.numelements,64);
verifyEqual(t,s.Trans.maxHighVoltage,35);
verifyEqual(t,s.TPC(1).hv,35);
verifyEqual(t,s.TW.Parameters,[6 .67 2 1]);
verifyEqual(t,s.TX.Apod,ones(1,64));
verifyEqual(t,s.TX.focus,20/(1.54/s.Trans.frequency),'AbsTol',1e-12);
verifyEqual(t,s.TX.Steer,[0 0]);
dist=sqrt(s.Trans.ElementPos(:,1)'.^2+s.TX.focus^2);
verifyEqual(t,s.TX.Delay,max(dist)-dist,'AbsTol',1e-10);
verifyEqual(t,evalin('base','exist(''Receive'',''var'')'),0);
verifyEqual(t,evalin('base','exist(''Recon'',''var'')'),0);
verifyEqual(t,evalin('base','exist(''Process'',''var'')'),0);
verifyEqual(t,numel(s.Event),451);
verifyEqual(t,sum([s.Event.tx]>0),450);
verifyTrue(t,all([s.Event.rcv]==0 & [s.Event.recon]==0 & [s.Event.process]==0));
verifyFalse(t,any(ismember({s.SeqControl.command},{'jump','transferToHost'})));
verifyEqual(t,s.SeqControl(s.Event(end).seqControl).command,'stop');
verifyEqual(t,s.SeqControl(1).argument,400);
verifyEqual(t,s.SeqControl(2).argument,14400);
verifyEqual(t,[s.Event(15:15:450).seqControl],2*ones(1,30));
end
