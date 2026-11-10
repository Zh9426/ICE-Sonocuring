function tests=curing_field_test_bli_prepare
%CURING_FIELD_TEST_BLI_PREPARE Unit tests for the band-limited curing source.
% Small grids only: no kspaceFirstOrder3D call, no VSX, no hardware. The tests
% check active-rank selection, per-element TX.Delay order, equal assumed signal
% amplitude, mask/signal row correspondence, per-edge support margins, sensor
% recording settings, and that the time window is not shorter than the original
% conservative prepare. The four actual exports are exercised when present.
tests=functiontests(localfunctions);
end

function setupOnce(t)
td=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(td));
addpath(root); addpath(td);
kw=fullfile(root,'dependencies','k-wave-1.4.1','k-Wave');
if ~isfolder(kw)
    kw=fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1');
end
addpath(kw);
t.TestData.root=root;
end

function testSmallGridSelectionDelaysWaveformAndSupport(t)
c=small_case([31 32 33 34],65e-6,1.3e-3,12e-6);
delays_us=[0.30 0.00 0.20 0.10];
s=delayed_mock(c.ranks,delays_us);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
save(f,'-struct','s');

[kg,medium,source,sensor,m,diag]=iceind.curing_bli_prepare(c,f);

verifyEqual(t,m.num_active,4);
verifyEqual(t,m.source_ranks,c.ranks);
verifyEqual(t,diag.delays_s,delays_us*1e-6,'AbsTol',1e-18);
b=iceind.compile_kwave(s);
verifyEqual(t,diag.positions_m,b.geometry.positions_m(c.ranks,:),'AbsTol',1e-15);
verifyEqual(t,m.element_width_m,0.11e-3,'AbsTol',1e-15);
verifyEqual(t,m.element_height_m,2.02e-3,'AbsTol',1e-15);

% One waveform, delayed copies in active-element order, equal peak amplitude.
sig=diag.signals;
ti=(0:size(sig,2)-1)*kg.dt;
for e=2:numel(delays_us)
    shift=(delays_us(e)-delays_us(1))*1e-6;
    shifted=interp1(ti,double(sig(1,:)),ti-shift,'linear',0);
    verifyEqual(t,double(sig(e,:)),shifted,'AbsTol',2e-2);
end
verifyEqual(t,diag.signal_peak_pa,ones(4,1),'AbsTol',0.05);
verifyLessThan(t,m.per_element_peak_sample_spread_relative,0.05);
% kw_waveform applies TX.Delay after a band-pass convolution, so compare the
% relative onset with the same-threshold onset of a zero-delay reference.
q=b.tx(1);
q0=q;
q0.delay_s=zeros(size(q0.delay_s));
[wave0,~]=iceind.kw_waveform(q0,kg.dt,m.wave_end_s,1);
ref=wave0(c.ranks(1),:);
refPeak=max(abs(double(ref)));
refIdx=find(abs(ref)>single(0.01*refPeak),1,'first');
assert(~isempty(refIdx),'Test reference waveform has no 1%-of-peak onset.');
refOnset=(refIdx-1)*kg.dt;
verifyEqual(t,diag.reference_onset_s,refOnset,'AbsTol',1e-15);
verifyEqual(t,m.filter_front_onset_s,refOnset,'AbsTol',1e-15);
relativeOnset=diag.signal_onset_s-refOnset;
verifyEqual(t,relativeOnset,delays_us*1e-6,'AbsTol',2*kg.dt);
verifyEqual(t,m.delay_application_max_error_s, ...
    max(abs(relativeOnset-delays_us*1e-6)),'AbsTol',1e-15);

% Per-edge support: every one of the six faces must be untouched and have at
% least one clear cell. Check each face explicitly, not only a bounding box.
faces={'x_lo','x_hi','y_lo','y_hi','z_lo','z_hi'};
for k=1:numel(faces)
    verifyGreaterThanOrEqual(t,m.support.margin_cells.(faces{k}),1);
    verifyFalse(t,m.support.nonzero_on_face.(faces{k}));
end
verifyFalse(t,m.support.touches_boundary);
verifyFalse(t,any(source.p_mask(1,:,:),'all'));
verifyFalse(t,any(source.p_mask(end,:,:),'all'));
verifyFalse(t,any(source.p_mask(:,1,:),'all'));
verifyFalse(t,any(source.p_mask(:,end,:),'all'));
verifyFalse(t,any(source.p_mask(:,:,1),'all'));
verifyFalse(t,any(source.p_mask(:,:,end),'all'));
gm=m.element_face_margin_m;
verifyGreaterThan(t,gm.x_lo,0); verifyGreaterThan(t,gm.x_hi,0);
verifyGreaterThan(t,gm.y_lo,0); verifyGreaterThan(t,gm.y_hi,0);
verifyGreaterThan(t,gm.z_lo,0); verifyGreaterThan(t,gm.z_hi,0);

% Mask and distributed signal rows correspond, and an independent rebuild of
% the array gives the same mask.
verifyEqual(t,size(source.p,1),nnz(source.p_mask));
verifyEqual(t,size(source.p,2),m.source_signal_samples);
verifyEqual(t,m.distributed_source.mask_points,nnz(source.p_mask));
verifyTrue(t,m.distributed_source.mask_signal_rows_match);
verifyTrue(t,m.verification.direct_checked);
verifyLessThan(t,m.verification.max_relative_mismatch,1e-5);
a=kWaveArray('BLITolerance',0.05,'UpsamplingRate',10,'BLIType','sinc', ...
    'SinglePrecision',true);
for e=1:4
    a.addRectElement([diag.positions_m(e,1),diag.positions_m(e,2),diag.source_z_m], ...
        diag.element_width_m,diag.element_height_m,[0 0 0]);
end
verifyTrue(t,isequal(source.p_mask,a.getArrayBinaryMask(kg)));

% Independent weighted delayed sum: proves every row of source.p corresponds
% to the mask point and every element's delay/order is carried into the source.
P=zeros(nnz(source.p_mask),size(sig,2),'single');
for e=1:4
    w=a.getElementGridWeights(kg,e);
    P=P+single(w(source.p_mask))*sig(e,:);
end
verifyLessThan(t,double(max(abs(P-source.p),[],'all')),1e-5);

% Full physical sensor mask and explicit recording settings.
verifyTrue(t,all(sensor.mask(:)));
verifyEqual(t,sensor.mask,true([numel(kg.x_vec) numel(kg.y_vec) numel(kg.z_vec)]));
verifyEqual(t,sensor.record,{'p_max_all','p_min_all','p_rms'});
verifyEqual(t,sensor.record_start_index,1);
verifyEqual(t,m.sensor_record_start_index,1);
verifyEqual(t,medium.sound_speed,1540);
verifyEqual(t,medium.density,1000);

% Time window covers the delayed source tail, the travel bound, and the
% minimum end time of the original conservative prepare.
verifyEqual(t,m.Nt,numel(kg.t_array));
verifyGreaterThanOrEqual(t,m.t_end_s,m.required_time_end_s-1e-12);
verifyGreaterThanOrEqual(t,m.t_end_s,m.baseline_original_prepare.required_time_end_s-1e-12);
verifyGreaterThanOrEqual(t,m.Nt,ceil(c.minimum_end_time_s/kg.dt)+1);

verifyEqual(t,m.source_scale_normalization,'per_element_reference_no_count_or_budget_match');
verifyTrue(t,contains(m.source_amplitude_definition,'not voltage calibrated'));
verifyTrue(t,contains(m.source_proxy_definition,'not acoustic power or energy'));
verifyTrue(t,contains(m.time_window_definition,'(Nt-1)*dt'));
verifyEqual(t,m.bli.tolerance,0.05);
verifyEqual(t,m.bli.upsampling_rate,10);
verifyTrue(t,isfinite(m.bli.spectrum_inband_l2_rel_error));
verifyGreaterThanOrEqual(t,m.bli.spectrum_inband_l2_rel_error,0);
verifyLessThan(t,m.bli.spectrum_inband_l2_rel_error,1);
verifyTrue(t,m.bli.mask_nonzero_points>0);
verifyTrue(t,contains(m.bli.ideal_aperture_spectrum_fraction_definition, ...
    'not a measured discrete alias error'));
verifyEqual(t,m.memory.source_matrix_bytes,nnz(source.p_mask)*m.source_signal_samples*4);
verifyTrue(t,m.memory.source_budget_checked_before_allocation);
verifyTrue(t,ismember(m.memory.source_budget_status, ...
    {'checked_against_memory_query','checked_against_explicit_budget'}));
verifyTrue(t,m.memory.source_within_limit);
verifyTrue(t,contains(m.memory.note,'not a solver peak-memory'));
end

function testTimeWindowNotShorterThanOriginalPrepare(t)
c=small_case([31 32 33 34],65e-6,1.3e-3,14e-6);
s=delayed_mock(c.ranks,[0.30 0.00 0.20 0.10]);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
save(f,'-struct','s');

[kg,~,~,~,m]=iceind.curing_bli_prepare(c,f);
[~,~,~,~,mOld]=iceind.curing_field_prepare(c,f);

verifyGreaterThanOrEqual(t,kg.t_array(end),mOld.t_end_s-1e-12);
verifyGreaterThanOrEqual(t,m.Nt,mOld.Nt);
verifyGreaterThanOrEqual(t,m.t_end_s,mOld.minimum_end_time_s);
verifyGreaterThanOrEqual(t,m.t_end_s,mOld.wave_end_s);
verifyGreaterThanOrEqual(t,m.Nt,ceil(c.minimum_end_time_s/kg.dt)+1);
end

function testBoundarySupportIsRejected(t)
% Rank 64 sits at +4.095 mm; with a 4.29 mm half-domain the BLI star crosses
% the +x face, so the adapter must refuse to hide the truncation.
c=small_case(64,65e-6,1.3e-3,4e-6,[8.58 5.2 5.2]*1e-3);
s=delayed_mock(c.ranks,0);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
save(f,'-struct','s');
verifyError(t,@() iceind.curing_bli_prepare(c,f),'iceind:CuringBLIBoundary');
end

function testMemoryBudgetIsCheckedBeforeAllocation(t)
c=small_case([31 32 33 34],65e-6,1.3e-3,4e-6);
s=delayed_mock(c.ranks,[0.30 0.00 0.20 0.10]);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
save(f,'-struct','s');
verifyError(t,@() iceind.curing_bli_prepare(c,f,struct('MaxSourceBytes',1)), ...
    'iceind:CuringBLIMemory');
[~,~,~,~,m]=iceind.curing_bli_prepare(c,f,struct('MaxSourceBytes',1e9));
verifyEqual(t,m.memory.source_budget_status,'checked_against_explicit_budget');
verifyTrue(t,m.memory.source_budget_checked_before_allocation);
verifyTrue(t,m.memory.source_within_limit);
end

function testRankMismatchIsRejected(t)
c=small_case([31 32],65e-6,1.3e-3,4e-6);
s=curing_field_mock_driver([31 33]);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
save(f,'-struct','s');
verifyError(t,@() iceind.curing_bli_prepare(c,f),'iceind:CuringBLIInput');
end

function testNoElementCountNormalization(t)
c1=small_case(32,65e-6,1.3e-3,4e-6);
c4=small_case(31:34,65e-6,1.3e-3,4e-6);
f1=[tempname '.mat']; cleanup1=onCleanup(@()delete_if(f1));
f4=[tempname '.mat']; cleanup4=onCleanup(@()delete_if(f4));
s1=curing_field_mock_driver(32); save(f1,'-struct','s1');
s4=delayed_mock(31:34,[0 0 0 0]); save(f4,'-struct','s4');

[~,~,~,~,m1,d1]=iceind.curing_bli_prepare(c1,f1);
[~,~,~,~,m4,d4]=iceind.curing_bli_prepare(c4,f4);

verifyEqual(t,d1.signal_peak_pa,1,'AbsTol',0.05);
verifyEqual(t,d4.signal_peak_pa,ones(4,1),'AbsTol',0.05);
verifyEqual(t,m1.source_amplitude_pa,1);
verifyEqual(t,m4.source_amplitude_pa,1);
% The source proxy is per-element pressure squared times nominal area; it grows
% with the number of active elements because there is no count normalisation.
verifyGreaterThan(t,m4.source_proxy_total_pa2_s_m2,3*m1.source_proxy_total_pa2_s_m2);
verifyLessThan(t,m4.source_proxy_total_pa2_s_m2,5*m1.source_proxy_total_pa2_s_m2);
verifyEqual(t,m4.per_element_peak_pa,ones(4,1),'AbsTol',0.05);
verifyEqual(t,m1.per_element_peak_pa,1,'AbsTol',0.05);
end

function testBLIOptionsAreRecordedNotHidden(t)
c=small_case([31 32 33 34],65e-6,1.3e-3,6e-6);
s=delayed_mock(c.ranks,[0.30 0.00 0.20 0.10]);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
save(f,'-struct','s');
[~,~,~,~,mBase]=iceind.curing_bli_prepare(c,f);
[~,~,~,~,mFine]=iceind.curing_bli_prepare(c,f, ...
    struct('BLITolerance',0.03,'UpsamplingRate',10,'SinglePrecision',true));
verifyEqual(t,mBase.bli.tolerance,0.05);
verifyEqual(t,mFine.bli.tolerance,0.03);
verifyGreaterThan(t,mFine.bli.mask_nonzero_points,mBase.bli.mask_nonzero_points);
verifyLessThan(t,mFine.bli.spectrum_75deg_rel_error,0.05);
verifyTrue(t,isfinite(mFine.bli.spectrum_inband_l2_rel_error));
verifyGreaterThanOrEqual(t,mFine.bli.spectrum_inband_l2_rel_error,0);
verifyFalse(t,mFine.support.touches_boundary);
verifyTrue(t,contains(mFine.bli.note,'not corrected'));
end

function testActualFourExports(t)
root=t.TestData.root;
variants=iceind.curing_field_variants();
for k=1:numel(variants)
    v=variants(k);
    word=uint64(0);
    for r=v.ranks
        word=bitor(word,bitshift(uint64(1),r-1));
    end
    name=sprintf('ICE_CuringOnly_Exposure%s_exposure_only.mat',upper(dec2hex(word,16)));
    mat=fullfile(root,'results','curing_export_2026-11-10',name);
    assumeTrue(t,isfile(mat),sprintf('Actual export unavailable: %s',name));

    c=small_case(v.ranks,65e-6,1.3e-3,4e-6);
    c.tag=sprintf('unit_actual_%s',lower(v.name));
    c.variant=v.name;
    [~,~,source,~,m,diag]=iceind.curing_bli_prepare(c,mat);

    verifyEqual(t,m.num_active,v.num_active);
    verifyEqual(t,m.source_ranks,v.ranks);
    verifyEqual(t,size(diag.positions_m,1),v.num_active);
    % Delays must be the actual exported geometric delays, not re-derived ones.
    target=[0 0 20]*1e-3;
    d=vecnorm(diag.positions_m-target,2,2);
    expected=(max(d)-d)/1540;
    verifyEqual(t,diag.delays_s,expected','AbsTol',1e-15);
    verifyLessThan(t,m.delay_vs_geometric_focus_max_error_s,1e-12);
    verifyFalse(t,m.support.touches_boundary);
    verifyLessThan(t,abs(m.bli.representative_scale_error_fraction),0.01);
    verifyLessThan(t,m.bli.spectrum_75deg_rel_error,0.05);
    verifyTrue(t,isfinite(m.bli.spectrum_inband_l2_rel_error));
    verifyGreaterThanOrEqual(t,m.bli.spectrum_inband_l2_rel_error,0);
    verifyGreaterThan(t,m.bli.ideal_aperture_spectrum_energy_fraction_outside_spatial_nyquist,0);
    verifyEqual(t,size(source.p,1),nnz(source.p_mask));
    verifyTrue(t,m.verification.direct_checked);
    verifyLessThan(t,m.verification.max_relative_mismatch,1e-5);
    verifyLessThan(t,m.per_element_peak_sample_spread_relative,0.05);
    verifyGreaterThanOrEqual(t,m.t_end_s,m.baseline_original_prepare.required_time_end_s-1e-12);
end
end

% -------------------------------------------------------------------------
function c=small_case(ranks,dx,offset,minimum_end_time_s,domain)
if nargin<5 || isempty(domain), domain=[10.4 5.2 5.2]*1e-3; end
c=struct();
c.tag='unit_small';
c.variant='UnitSmall';
c.entry='unit_mock';
c.ranks=ranks;
c.num_active=numel(ranks);
c.dx_m=dx;
c.domain_m=domain;
c.pml_m=0.52e-3;
c.cfl=0.2;
c.density_kg_m3=1000;
c.sound_speed_m_s=1540;
c.source_offset_m=offset;
c.source_amplitude_pa=1;
c.minimum_end_time_s=minimum_end_time_s;
c.output_dir=tempdir;
c.provenance='synthetic_unit_test_assumed';
end

function s=delayed_mock(ranks,delays_us)
s=curing_field_mock_driver(ranks);
s.TX.Delay(:)=0;
s.TX.Delay(ranks)=delays_us(:)'*6.5; % TX.Delay is in cycles of Trans.frequency
end

function delete_if(f)
if isfile(f), delete(f); end
end
