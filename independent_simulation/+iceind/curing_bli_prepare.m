function [kg,medium,source,sensor,m,diag]=curing_bli_prepare(c,driverMat,opts)
%CURING_BLI_PREPARE Build a CPU k-Wave problem with a band-limited finite-rectangle source.
% The saved curing sequence MAT is the only source of geometry and timing:
% active ranks, element centres, element width/elevation, and every element's
% TX.Delay are taken from the export through iceind.compile_kwave. Each active
% element receives the SAME assumed reference pressure signal (delayed copies
% of one waveform, 1 Pa by default). No per-element, aperture-count, or
% source-budget normalisation is applied. The physical 0.11 x 2.02 mm
% rectangles are represented with kWaveArray band-limited interpolants (BLI,
% Wise et al., JASA 2019). BLI truncation and spatial-aliasing metrics are
% reported in the metadata, not hidden or silently corrected.
%
% The returned sensor mask is the whole physical domain and records p_max_all,
% p_min_all and p_rms with an explicit record_start_index = 1. The time window
% is never shorter than the conservative window of curing_field_prepare: the
% latest delayed source tail plus one aperture-to-far-corner travel bound, and
% at least c.minimum_end_time_s.
%
% Assumptions, not measurements: homogeneous lossless fluid, flat rectangular
% pressure sources without an elevation lens, and an assumed 1 Pa reference per
% element that is not voltage calibrated. Pressure peaks and the pressure-square
% proxy are not acoustic power, acoustic energy, heating, dose, or cure.
%
% Per-element TX.Delay is checked against the same-threshold onset of a
% zero-delay reference waveform, so the common band-pass filter front delay
% cancels; the raw 1%-onset is not compared with TX.Delay. The source-matrix
% byte budget is checked before getDistributedSourceSignal allocates it.
%
% [kg,medium,source,sensor,m,diag]=CURING_BLI_PREPARE(c,driverMat,opts)
%
% c          - case struct from iceind.curing_field_cases (or a test case with
%              the same fields: ranks, dx_m, domain_m, pml_m, cfl,
%              density_kg_m3, source_offset_m, source_amplitude_pa,
%              minimum_end_time_s).
% driverMat  - actual exported SetUp MAT, or a unit-test mock with the same
%              fields consumed by iceind.compile_kwave.
% opts       - optional struct:
%              BLITolerance (0.05), UpsamplingRate (10), BLIType ('sinc'),
%              SinglePrecision (true), VerifyDistributedSource (true),
%              VerifyTolerance (1e-5), MaxSourceBytes ([] = 60% of MATLAB's
%              memory query; if that query is unavailable, a finite explicit
%              budget is required before the source matrix is allocated).
%
% m          - metadata (provenance, waveform, support margins, aliasing,
%              memory estimate, time-window definitions).
% diag       - extra test information (active ranks/positions/delays, binary
%              mask, per-element signals and onsets, direct-check results).

if nargin<3 || isempty(opts), opts=struct(); end
opts=local_options(opts);

% ---------------- saved sequence: selection, geometry, delays ----------------
assert(isstruct(c),'iceind:CuringBLIInput','Case must be a struct.');
required={'tag','variant','ranks','dx_m','domain_m','pml_m','cfl', ...
    'density_kg_m3','source_offset_m','source_amplitude_pa','minimum_end_time_s'};
for k=1:numel(required)
    assert(isfield(c,required{k}) && ~isempty(c.(required{k})), ...
        'iceind:CuringBLIInput',sprintf('Case field %s is required.',required{k}));
end
assert(isfile(driverMat),'iceind:CuringBLIInput',sprintf('Missing driver MAT: %s',driverMat));
s=load(driverMat);
assert(isfield(s,'ICEConfig') && isfield(s.ICEConfig,'partition') && ...
    isfield(s.ICEConfig.partition,'exposure_ranks'),'iceind:CuringBLIInput', ...
    'Driver MAT lacks ICEConfig.partition.exposure_ranks.');
ranks=sort(double(c.ranks(:)'));
assert(isequal(ranks,sort(double(s.ICEConfig.partition.exposure_ranks(:)'))), ...
    'iceind:CuringBLIInput','Driver rank mask does not match the requested case.');
b=iceind.compile_kwave(s);
assert(numel(b.tx)==1,'iceind:CuringBLIInput','Expected exactly one exposure TX.');
q=b.tx(1);
active=find(q.apod(:)~=0)';
assert(isequal(active,ranks),'iceind:CuringBLIInput', ...
    'TX apodization does not activate exactly the requested ranks.');
assert(all(q.apod(active)==1),'iceind:CuringBLIInput', ...
    ['Active elements must all have Apod = +1 so that every element keeps the ' ...
     'same signal amplitude and polarity; PWM/negative apodization is not approximated.']);
positions=b.geometry.positions_m;
assert(isscalar(b.geometry.width_m) && isscalar(b.geometry.height_m), ...
    'iceind:CuringBLIGeometry','Element width/height must be scalars.');
width=double(b.geometry.width_m);
height=double(b.geometry.height_m);
area=width*height;
assert(abs(width-0.11e-3)<1e-12 && abs(height-2.02e-3)<1e-12, ...
    'iceind:CuringBLIGeometry',sprintf( ...
    'Expected the 0.11 x 2.02 mm probe rectangle, got %.6g x %.6g m.',width,height));
assert(size(positions,1)==numel(q.apod) && all(isfinite(positions(:))), ...
    'iceind:CuringBLIGeometry','Invalid element positions.');

% ---------------- physical grid and source plane ----------------
domain=double(c.domain_m(:)');
dx=double(c.dx_m);
assert(numel(domain)==3 && all(domain>0) && isscalar(dx) && dx>0, ...
    'iceind:CuringBLIGeometry','Invalid domain or grid spacing.');
n=round(domain/dx);
pml=round(double(c.pml_m)/dx);
assert(all(abs(n*dx-domain)<1e-12),'iceind:CuringBLIGeometry', ...
    'Grid spacing must divide the physical domain exactly.');
assert(pml>0 && abs(pml*dx-double(c.pml_m))<1e-12,'iceind:CuringBLIGeometry', ...
    'PML thickness must be an integer number of cells.');
kg=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
sourceZ=-domain(3)/2+double(c.source_offset_m);
[~,sourceIz]=min(abs(kg.z_vec-sourceZ));
assert(abs(kg.z_vec(sourceIz)-sourceZ)<1e-12,'iceind:CuringBLIGeometry', ...
    'Source plane must land on a grid plane.');

% ---------------- conservative time window (never shorter than baseline) ----
delay=reshape(q.delay_s(active),1,[]);
waveEnd=max(q.delay_s)+q.duration_s+2e-6;
supportRadiusCells=ceil(1/(pi*opts.BLITolerance));
supportRadius_m=supportRadiusCells*dx;
boundX=domain(1)/2+max(abs(positions(active,1)))+width/2+supportRadius_m;
boundY=domain(2)/2+max(abs(positions(active,2)))+height/2+supportRadius_m;
boundZ=domain(3)-double(c.source_offset_m)+supportRadius_m;
distance=sqrt(boundX^2+boundY^2+boundZ^2);
oneWay=distance/b.sound_speed_m_s;
kg.makeTime(b.sound_speed_m_s,double(c.cfl),waveEnd+oneWay+1e-6);
kg.setTime(max(kg.Nt,ceil(double(c.minimum_end_time_s)/kg.dt)+1),kg.dt);
baseDistance=sqrt((domain(1)/2+max(abs(positions(active,1))))^2+ ...
    (domain(2)/2+height/2)^2+(domain(3)-double(c.source_offset_m))^2);
baseWaveEnd=max(q.delay_s)+q.duration_s+2e-6;
baseEnd=baseWaveEnd+baseDistance/b.sound_speed_m_s+1e-6;
baseNt=ceil(double(c.minimum_end_time_s)/kg.dt)+1;
assert(kg.t_array(end)>=baseEnd-1e-12 && kg.Nt>=baseNt,'iceind:CuringBLITime', ...
    'Time window is shorter than the conservative baseline window.');

% ---------------- one assumed waveform per active element ----------------
[wave,wm]=iceind.kw_waveform(q,kg.dt,waveEnd,double(c.source_amplitude_pa));
sig=wave(active,:);
waveformSamples=numel(0:kg.dt:waveEnd);
assert(size(sig,1)==numel(active) && size(sig,2)==waveformSamples && ...
    waveformSamples<=kg.Nt,'iceind:CuringBLISource', ...
    'Per-element signals do not match the active elements or time axis.');
peak=max(abs(double(sig)),[],2);
assert(all(peak>0),'iceind:CuringBLISource','An active element has an all-zero signal.');
spread=(max(peak)-min(peak))/mean(peak);
onset=zeros(1,numel(active));
for e=1:numel(active)
    idx=find(abs(sig(e,:))>single(0.01*peak(e)),1,'first');
    assert(~isempty(idx),'iceind:CuringBLISource', ...
        sprintf('Missing signal onset for element %d.',e));
    onset(e)=double(idx-1)*kg.dt;
end
% kw_waveform applies the TX.Delay after a Gaussian band-pass convolution, so
% the absolute 1%-of-peak onset also contains the common filter front delay
% (not equal to the group delay). Compare each element's onset with the onset
% of the SAME waveform built with zero TX.Delay and the SAME threshold.
q0=q;
q0.delay_s=zeros(size(q.delay_s));
[wave0,~]=iceind.kw_waveform(q0,kg.dt,waveEnd,double(c.source_amplitude_pa));
ref0=wave0(active(1),:);
refPeak=max(abs(double(ref0)));
assert(refPeak>0,'iceind:CuringBLISource','Zero-delay reference waveform is all zero.');
refIdx=find(abs(ref0)>single(0.01*refPeak),1,'first');
assert(~isempty(refIdx),'iceind:CuringBLISource', ...
    'Zero-delay reference waveform has no 1%-of-peak onset.');
referenceOnset=double(refIdx-1)*kg.dt;
relativeOnset=onset-referenceOnset;
onsetError=max(abs(relativeOnset-delay));
assert(onsetError<=2*kg.dt+1e-12,'iceind:CuringBLISource', ...
    ['Per-element TX.Delay was not applied in element order: relative 1%-onset ' ...
     'differs from TX.Delay.']);
lastSignalIndex=find(any(abs(sig)>0,1),1,'last');
sourceTailEnd=(lastSignalIndex-1)*kg.dt;
requiredEnd=sourceTailEnd+oneWay+1e-6;
assert(kg.t_array(end)>=requiredEnd-1e-12,'iceind:CuringBLITime', ...
    'Time window does not cover the delayed source tail plus travel bound.');

% ---------------- band-limited rectangular source ----------------
a=kWaveArray('BLITolerance',opts.BLITolerance, ...
    'UpsamplingRate',opts.UpsamplingRate, ...
    'BLIType',opts.BLIType, ...
    'SinglePrecision',opts.SinglePrecision);
for e=1:numel(active)
    a.addRectElement([positions(active(e),1),positions(active(e),2),sourceZ], ...
        width,height,[0 0 0]);
end
assert(a.number_elements==numel(active),'iceind:CuringBLISource', ...
    'kWaveArray element count does not match the active ranks.');
elementPositions=reshape([positions(active,1:2),repmat(sourceZ,numel(active),1)]',3,[]);
assert(max(abs(a.getElementPositions()-elementPositions),[],'all')<1e-12, ...
    'iceind:CuringBLISource','kWaveArray element positions do not match the MAT.');

mask=a.getArrayBinaryMask(kg);
assert(any(mask(:)) && nnz(mask)<prod(n),'iceind:CuringBLISource', ...
    'Band-limited source mask is empty or fills the whole domain.');
support=local_support(kg,mask);
support.definition=['kWaveArray.getArrayBinaryMask, i.e. the truncated BLI star ' ...
    'extent (conservative; some star points can carry zero weight)'];
assert(~support.touches_boundary,'iceind:CuringBLIBoundary', ...
    sprintf(['Band-limited source support touches the physical-domain boundary ' ...
     '(%s). Move the source, enlarge the domain, or tighten BLITolerance.'], ...
    support.touching_faces));
geomMargin=local_element_margins(positions(active,:),width,height,sourceZ,domain);
assert(all(cell2mat(struct2cell(geomMargin))>0),'iceind:CuringBLIBoundary', ...
    'Nominal element geometry crosses the physical-domain boundary.');

% ---------------- source-matrix budget BEFORE allocation ----------------
% The distributed-source matrix is the dominant new allocation. Its row count
% and time-sample count are already known here, so check the budget before
% getDistributedSourceSignal allocates it. If the MATLAB memory query is not
% available, an explicit MaxSourceBytes budget is required; Inf is never
% treated as a pass.
if isempty(opts.MaxSourceBytes)
    try
        mem=memory;
        availableBytes=double(mem.MaxPossibleArrayBytes);
    catch
        availableBytes=NaN;
    end
    if isempty(availableBytes) || ~isfinite(availableBytes) || availableBytes<=0
        error('iceind:CuringBLIMemory',['MATLAB memory query unavailable. Pass ' ...
            'opts.MaxSourceBytes as a finite positive byte budget before the ' ...
            'distributed source matrix is allocated.']);
    end
    limitBytes=0.6*availableBytes;
    sourceBudgetStatus='checked_against_memory_query';
else
    availableBytes=NaN;
    limitBytes=double(opts.MaxSourceBytes);
    sourceBudgetStatus='checked_against_explicit_budget';
end
bytesPerSample=4+4*double(~opts.SinglePrecision);
sourceBytes=nnz(mask)*waveformSamples*bytesPerSample;
sensorBytes=3*prod(n)*4;            % finite estimate, not a peak-memory check
stateBytes=prod(n+2*pml)*4*8;       % finite estimate, not a peak-memory check
totalBytes=sourceBytes+sensorBytes+stateBytes;
assert(sourceBytes<=limitBytes,'iceind:CuringBLIMemory', ...
    sprintf(['Estimated source matrix %.3f GB exceeds the %.3f GB allowance. ' ...
     'Raise BLITolerance, use SinglePrecision, or shorten the test window.'], ...
    sourceBytes/2^30,limitBytes/2^30));

source=struct();
source.p_mask=mask;
source.p_mode='additive';
dist=a.getDistributedSourceSignal(kg,sig);
assert(size(dist,1)==nnz(mask),'iceind:CuringBLISource', ...
    sprintf('Distributed source rows (%d) do not match the source mask (%d).', ...
    size(dist,1),nnz(mask)));
assert(all(isfinite(dist(:))),'iceind:CuringBLISource', ...
    'Distributed source contains non-finite values.');
source.p=dist;

% ---------------- BLI representation / aliasing diagnostics ----------------
repIndex=ceil(numel(active)/2);
wrep=a.getElementGridWeights(kg,repIndex);
repTotal=double(sum(wrep,'all'));
expectedWeightSum=area/dx^2;
scaleError=(repTotal-expectedWeightSum)/expectedWeightSum;
xz=double(squeeze(sum(wrep,2)));
fx=sind(75)*q.frequency_hz/b.sound_speed_m_s;
fz=cosd(75)*q.frequency_hz/b.sound_speed_m_s;
spectralNumerator=abs((exp(-2i*pi*fx*kg.x_vec(:)).')*xz* ...
    exp(-2i*pi*fz*kg.z_vec(:)))/repTotal;
spectralIdeal=abs(local_sinc(width*fx));
spectrum75Error=abs(spectralNumerator-spectralIdeal)/spectralIdeal;
spatialNyquist=1/(2*dx);
% Full in-band 2-D aperture-spectrum error on the representative element. The
% DTFT of the grid weights is compared with the continuous rectangle transform
% only inside the representable spatial band; out-of-band content is reported
% separately and is not silently folded into this number.
w2=double(squeeze(sum(wrep,3)));
w2=w2/sum(w2(:));
nPad=2*2^nextpow2(max(size(w2)));
F2=fftshift(fft2(w2,nPad,nPad));
freqAxis=(-nPad/2:nPad/2-1)/(nPad*dx);
[FX,FY]=ndgrid(freqAxis,freqAxis);
inBand=abs(FX)<=spatialNyquist & abs(FY)<=spatialNyquist;
ideal2=abs(local_sinc(width*FX).*local_sinc(height*FY));
bandError=abs(abs(F2)-ideal2);
spectrumInBandL2=sqrt(sum(bandError(inBand).^2)/sum(ideal2(inBand).^2));
spectrumInBandMax=max(bandError(inBand));
idealOutOfBandFraction=max(0,1-local_band_energy_fraction(width,spatialNyquist)* ...
    local_band_energy_fraction(height,spatialNyquist));
clear wrep xz w2 F2 FX FY ideal2 bandError

fftLength=2^nextpow2(size(sig,2)*4);
spec=abs(fft(double(sig(1,:)),fftLength)).^2;
freq=(0:fftLength/2)/(fftLength*kg.dt);
spec=spec(1:numel(freq));
temporalAliasFraction=sum(spec(freq>b.sound_speed_m_s/(2*dx)))/sum(spec);

% ---------------- direct check of mask/signal/order/delay correspondence ----
if opts.VerifyDistributedSource
    ver=local_verify(a,kg,mask,dist,sig,opts.VerifyTolerance,expectedWeightSum);
else
    ver=struct('direct_checked',false,'max_relative_mismatch',NaN, ...
        'columns_checked',0,'tolerance',opts.VerifyTolerance, ...
        'per_element_scale_error',[],'note','direct distributed-source check skipped by option');
end
if ver.direct_checked
    assert(ver.max_relative_mismatch<=opts.VerifyTolerance,'iceind:CuringBLISource', ...
        sprintf(['Distributed source does not equal the per-element weighted ' ...
        'delayed sum (%.3g > %.3g).'],ver.max_relative_mismatch,opts.VerifyTolerance));
end

% ---------------- metadata ----------------
medium=struct('sound_speed',b.sound_speed_m_s,'density',double(c.density_kg_m3));
sensor=struct();
sensor.mask=true(n);
sensor.record={'p_max_all','p_min_all','p_rms'};
sensor.record_start_index=1;

target=double(s.ICEConfig.exposure.foci_mm(1,:))*1e-3;
assert(norm(target-[0 0 20e-3])<0.5e-3,'iceind:CuringBLITarget', ...
    'Exported focus is not the assumed 20 mm on-axis target.');
if isfield(s,'synthetic_focus_depth_mm')
    assert(ismember(s.synthetic_focus_depth_mm,[16 18 20 22]),'iceind:CuringBLITarget', ...
        'Unsupported synthetic focus depth.');
    target=[0 0 double(s.synthetic_focus_depth_mm)*1e-3];
end
activeX=sort(positions(active,1));
span=max(activeX)-min(activeX)+width;
perElementProxy=area*kg.dt*sum(double(sig).^2,2);
totalProxy=sum(perElementProxy);
dGeom=vecnorm(positions(active,:)-target,2,2);
geomDelay=(max(dGeom)-dGeom)/b.sound_speed_m_s;
delayGeomError=max(abs(delay-geomDelay'));
arrival=delay'+vecnorm(positions(active,:)-target,2,2)/b.sound_speed_m_s;
arrivalSpread=max(arrival)-min(arrival);

bli=struct();
bli.type=opts.BLIType;
bli.tolerance=opts.BLITolerance;
bli.upsampling_rate=opts.UpsamplingRate;
bli.single_precision=opts.SinglePrecision;
bli.number_elements=numel(active);
bli.mask_nonzero_points=nnz(mask);
bli.representative_element_index=repIndex;
bli.representative_weight_sum=repTotal;
bli.expected_weight_sum_area_over_dx2=expectedWeightSum;
bli.representative_scale_error_fraction=scaleError;
bli.spectrum_75deg_rel_error=spectrum75Error;
bli.spectrum_inband_l2_rel_error=spectrumInBandL2;
bli.spectrum_inband_max_abs_error=spectrumInBandMax;
bli.spectrum_inband_definition=['|| |DTFT(grid weights)| - |sinc(width*fx)*' ...
    'sinc(height*fy)| || over |fx|,|fy| <= 1/(2*dx), normalized by the ' ...
    'ideal in-band L2 norm; zero-padded 2-D FFT of the representative element'];
bli.ideal_aperture_spectrum_energy_fraction_outside_spatial_nyquist=idealOutOfBandFraction;
bli.ideal_aperture_spectrum_fraction_definition=['1 - Px*Py for the ideal ' ...
    'continuous separable rectangle; P is the exact 1-D fraction of sinc^2 ' ...
    'aperture-spectrum energy inside |f| <= 1/(2dx), using an analytic ' ...
    'denominator 1/W and adaptive quadrature of the numerator over [0,W*F]. ' ...
    'This describes the ideal aperture, not a measured discrete alias error or ' ...
    'a propagation error.'];
bli.spatial_nyquist_per_m=spatialNyquist;
bli.spectral_energy_above_spatial_nyquist_fraction=temporalAliasFraction;
bli.temporal_nyquist_hz=1/(2*kg.dt);
bli.points_per_wavelength=b.sound_speed_m_s/(q.frequency_hz*dx);
bli.note=['BLI truncation and spatial-aliasing metrics are reported; ' ...
    'ideal-aperture spectrum outside the grid spatial Nyquist cannot be ' ...
    'represented and is not corrected.'];
if ver.direct_checked && ~isempty(ver.per_element_scale_error)
    bli.per_element_scale_error_min=min(ver.per_element_scale_error);
    bli.per_element_scale_error_max=max(ver.per_element_scale_error);
else
    bli.per_element_scale_error_min=NaN;
    bli.per_element_scale_error_max=NaN;
end

m=struct();
m.schema_version=1;
m.case_tag=c.tag;
m.variant=c.variant;
m.driver_mat=driverMat;
m.driver_sha256=iceind.curing_field_sha256(driverMat);
m.num_active=numel(active);
m.source_ranks=ranks;
m.source_positions_m=positions(active,:);
m.delays_s=delay;
m.delay_source='TX.Delay converted with Trans.frequency by iceind.compile_kwave';
m.delay_vs_geometric_focus_max_error_s=delayGeomError;
m.active_center_arrival_spread_s=arrivalSpread;
m.source_geometry_provenance=b.geometry.provenance;
m.elevation_focus_m_metadata=b.geometry.elevation_focus_m_metadata;
m.elevation_lens_model=b.geometry.elevation_lens_model;
m.medium_provenance=local_get(c,'provenance','assumed');
m.pml_cells=pml;
m.dx_m=dx;
m.source_z_offset_m=double(c.source_offset_m);
m.source_z_kgrid_m=sourceZ;
m.dt_s=kg.dt;
m.Nt=kg.Nt;
m.source_signal_samples=waveformSamples;
m.t_end_s=kg.t_array(end);
m.minimum_end_time_s=double(c.minimum_end_time_s);
m.wave_end_s=waveEnd;
m.source_tail_end_s=sourceTailEnd;
m.untruncated_waveform_duration_s=wm.acoustic_duration_s;
m.required_time_end_s=requiredEnd;
m.one_way_bound_s=oneWay;
m.one_way_bound_definition=['aperture-to-far-corner distance including element ' ...
    'half-width/half-height and the BLI support radius ceil(1/(pi*tolerance))'];
m.baseline_original_prepare=struct('wave_end_s',baseWaveEnd, ...
    'one_way_bound_s',baseDistance/b.sound_speed_m_s,'required_time_end_s',baseEnd, ...
    'minimum_samples',baseNt);
m.time_window_definition=['(Nt-1)*dt with Nt=max(kg.Nt,ceil(minimum_end_time_s/dt)+1); ' ...
    'includes the latest delayed source tail, the BLI-inclusive one-way bound, ' ...
    'and a 1 us margin; never shorter than curing_field_prepare'];
m.time_window_not_shorter_than_baseline=true;
m.element_width_m=width;
m.element_height_m=height;
m.element_area_m2=area;
m.active_area_m2=area*numel(active);
if numel(activeX)>1
    m.active_pitch_m=median(diff(activeX));
else
    m.active_pitch_m=NaN;
end
m.active_pitch_definition=['median adjacent active-element pitch; NaN when fewer ' ...
    'than two elements are active'];
m.active_center_x_m=mean(activeX);
m.aperture_span_m=span;
m.fill_fraction_of_span=area*numel(active)/(span*height);
m.f_number_target_over_span=target(3)/span;
m.waveform=wm;
m.source_amplitude_definition=['assumed equal reference pressure per element; ' ...
    'not voltage calibrated'];
m.source_amplitude_pa=double(c.source_amplitude_pa);
m.equal_signal_scale_across_elements=true;
m.source_scale_normalization='per_element_reference_no_count_or_budget_match';
m.per_element_peak_pa=peak;
m.per_element_peak_sample_spread_relative=spread;
m.filter_front_onset_s=referenceOnset;
m.onset_definition=['first sample where |signal| > 1% of its peak; per-element ' ...
    'TX.Delay is checked as (element onset - zero-delay reference onset), which ' ...
    'removes the common band-pass filter front delay'];
m.delay_application_max_error_s=onsetError;
m.source_proxy_total_pa2_s_m2=totalProxy;
m.per_element_proxy_pa2_s_m2=perElementProxy;
m.source_proxy_definition=['sum_e nominal_element_area*dt*sum_t(s_e(t)^2); ' ...
    'Pa^2 s m^2; not acoustic power or energy'];
m.spectral_energy_above_spatial_nyquist_fraction=temporalAliasFraction;
m.points_per_wavelength=b.sound_speed_m_s/(q.frequency_hz*dx);
m.source_model=['assumed_equal_per_element_band_limited_flat_rectangular_' ...
    'pressure_kWaveArray_additive_no_lens'];
m.solver='kspaceFirstOrder3D';
m.solver_device='cpu';
m.suggested_data_cast='single';
m.bli=bli;
m.support=support;
m.element_face_margin_m=geomMargin;
m.sensor_mask_definition=['sensor.mask is all true on the n-cell k-Wave grid; the ' ...
    'intended runner uses PMLInside=false and PMLSize=pml so the absorbing layer ' ...
    'is outside this mask'];
m.sensor_record=sensor.record;
m.sensor_record_start_index=sensor.record_start_index;
m.distributed_source=struct('mask_points',nnz(mask),'signal_rows',size(dist,1), ...
    'mask_signal_rows_match',size(dist,1)==nnz(mask), ...
    'mask_definition','kWaveArray.getArrayBinaryMask', ...
    'signal_definition','kWaveArray.getDistributedSourceSignal of the delayed per-element signals');
m.verification=ver;
m.memory=struct('source_matrix_bytes',sourceBytes,'sensor_arrays_bytes',sensorBytes, ...
    'solver_state_bytes_estimate',stateBytes,'total_estimate_bytes',totalBytes, ...
    'available_bytes',availableBytes,'source_allowance_bytes',limitBytes, ...
    'source_budget_status',sourceBudgetStatus, ...
    'source_budget_checked_before_allocation',true, ...
    'source_within_limit',sourceBytes<=limitBytes, ...
    'note',['source_within_limit covers only the distributed-source matrix before ' ...
    'allocation. sensor/state bytes are finite estimates, not a solver peak-memory ' ...
    'check; p_final and other runner allocations are not included. Estimates assume ' ...
    'the caller uses DataCast=''single'' as suggested; double-precision solver ' ...
    'arrays roughly double the sensor/state terms']);
m.assumptions={ ...
    'Homogeneous lossless fluid; no absorption, nonlinearity, backing, lens, coupling layer, container or SonoInk reaction.'; ...
    'Each active element uses the same assumed 1 Pa reference pressure signal delayed by its exported TX.Delay; amplitudes are not normalised by element count or a source budget.'; ...
    'Flat 0.11 x 2.02 mm rectangular pressure sources with BLI; source support margins and aliasing metrics are recorded, not assumed harmless.'; ...
    'Pressure peaks, p_rms-derived quantities and the pressure-square proxy are not acoustic power, acoustic energy, heating, dose, safety or cure.'};
m.grid_size=n;
m.grid_with_pml=n+2*pml;
m.domain_m=domain;
m.foci_mm=target*1e3;
m.target_m=target;

diag=struct();
diag.active=active;
diag.positions_m=positions(active,:);
diag.delays_s=delay;
diag.element_width_m=width;
diag.element_height_m=height;
diag.element_area_m2=area;
diag.source_z_m=sourceZ;
diag.source_iz=sourceIz;
diag.mask=mask;
diag.mask_nnz=nnz(mask);
diag.support=support;
diag.element_face_margin_m=geomMargin;
diag.bli=bli;
diag.signal_peak_pa=peak;
diag.signal_onset_s=onset;
diag.reference_onset_s=referenceOnset;
diag.relative_onset_s=relativeOnset;
diag.expected_delay_s=delay;
diag.signals=sig;
diag.waveform=wm;
diag.verification=ver;
diag.one_way_bound_s=oneWay;
diag.required_time_end_s=requiredEnd;
end

% =========================================================================
function opts=local_options(opts)
defaults=struct('BLITolerance',0.05,'UpsamplingRate',10,'BLIType','sinc', ...
    'SinglePrecision',true,'VerifyDistributedSource',true, ...
    'VerifyTolerance',1e-5,'MaxSourceBytes',[]);
names=fieldnames(defaults);
for k=1:numel(names)
    if ~isfield(opts,names{k}) || isempty(opts.(names{k}))
        opts.(names{k})=defaults.(names{k});
    end
end
validateattributes(opts.BLITolerance,{'numeric'},{'real','scalar','>',0,'<',1}, ...
    'curing_bli_prepare','BLITolerance');
validateattributes(opts.UpsamplingRate,{'numeric'},{'real','scalar','integer','>',0}, ...
    'curing_bli_prepare','UpsamplingRate');
assert(ischar(opts.BLIType) && strcmpi(opts.BLIType,'sinc'), ...
    'iceind:CuringBLIInput',['Only BLIType ''sinc'' is supported; an exact BLI ' ...
    'has global support and would be clipped by the finite domain.']);
opts.BLIType='sinc';
validateattributes(opts.SinglePrecision,{'logical','numeric'},{'scalar'}, ...
    'curing_bli_prepare','SinglePrecision');
opts.SinglePrecision=logical(opts.SinglePrecision);
validateattributes(opts.VerifyDistributedSource,{'logical','numeric'},{'scalar'}, ...
    'curing_bli_prepare','VerifyDistributedSource');
opts.VerifyDistributedSource=logical(opts.VerifyDistributedSource);
validateattributes(opts.VerifyTolerance,{'numeric'},{'real','scalar','>',0}, ...
    'curing_bli_prepare','VerifyTolerance');
if ~isempty(opts.MaxSourceBytes)
    validateattributes(opts.MaxSourceBytes,{'numeric'}, ...
        {'real','scalar','finite','>',0},'curing_bli_prepare','MaxSourceBytes');
end
end

function v=local_get(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), v=s.(name); else, v=default; end
end

function support=local_support(kg,mask)
n=size(mask);
[ix,iy,iz]=ind2sub(n,find(mask));
support=struct();
support.nonzero_points=nnz(mask);
support.bounding_box_indices=[min(ix) max(ix);min(iy) max(iy);min(iz) max(iz)];
support.bounding_box_m=[kg.x_vec(min(ix)) kg.x_vec(max(ix)); ...
    kg.y_vec(min(iy)) kg.y_vec(max(iy));kg.z_vec(min(iz)) kg.z_vec(max(iz))];
support.margin_cells=struct('x_lo',min(ix)-1,'x_hi',n(1)-max(ix), ...
    'y_lo',min(iy)-1,'y_hi',n(2)-max(iy), ...
    'z_lo',min(iz)-1,'z_hi',n(3)-max(iz));
support.margin_m=struct('x_lo',(min(ix)-1)*kg.dx,'x_hi',(n(1)-max(ix))*kg.dx, ...
    'y_lo',(min(iy)-1)*kg.dy,'y_hi',(n(2)-max(iy))*kg.dy, ...
    'z_lo',(min(iz)-1)*kg.dz,'z_hi',(n(3)-max(iz))*kg.dz);
support.min_margin_cells=min(cell2mat(struct2cell(support.margin_cells)));
support.min_margin_m=min(cell2mat(struct2cell(support.margin_m)));
support.nonzero_on_face=struct('x_lo',any(mask(1,:,:),'all'), ...
    'x_hi',any(mask(end,:,:),'all'),'y_lo',any(mask(:,1,:),'all'), ...
    'y_hi',any(mask(:,end,:),'all'),'z_lo',any(mask(:,:,1),'all'), ...
    'z_hi',any(mask(:,:,end),'all'));
faces=fieldnames(support.nonzero_on_face);
touching={};
for k=1:numel(faces)
    if support.nonzero_on_face.(faces{k}), touching{end+1}=faces{k}; end %#ok<AGROW>
end
support.touching_faces=strjoin(touching,',');
support.touches_boundary=~isempty(touching);
end

function margin=local_element_margins(positions,width,height,sourceZ,domain)
x=positions(:,1); y=positions(:,2); z=positions(:,3)+sourceZ;
margin=struct();
margin.x_lo=min(x)-width/2+domain(1)/2;
margin.x_hi=domain(1)/2-(max(x)+width/2);
margin.y_lo=min(y)-height/2+domain(2)/2;
margin.y_hi=domain(2)/2-(max(y)+height/2);
margin.z_lo=min(z)+domain(3)/2;
margin.z_hi=domain(3)/2-max(z);
end

function ver=local_verify(a,kg,mask,dist,sig,tolerance,expectedWeightSum)
mag=max(abs(sig),[],1);
first=find(mag>0,1,'first');
[~,peakIndex]=max(mag);
columns=unique([first,peakIndex,size(sig,2)]);
cls=class(dist);
direct=zeros(nnz(mask),numel(columns),cls);
scaleError=zeros(1,size(sig,1));
for e=1:size(sig,1)
    w=a.getElementGridWeights(kg,e);
    direct=direct+cast(w(mask),cls)*cast(sig(e,columns),cls);
    scaleError(e)=(double(sum(w,'all'))-expectedWeightSum)/expectedWeightSum;
end
ver=struct();
ver.direct_checked=true;
ver.columns_checked=numel(columns);
ver.tolerance=tolerance;
ver.max_relative_mismatch=max(abs(direct-dist(:,columns)),[],'all')/ ...
    max(1,max(abs(dist(:,columns)),[],'all'));
ver.per_element_scale_error=scaleError;
ver.note='direct weighted delayed-sum check at onset, peak and final sample';
end

function y=local_sinc(x)
y=ones(size(x));
nz=x~=0;
y(nz)=sin(pi*x(nz))./(pi*x(nz));
end

function p=local_band_energy_fraction(W,F)
% Exact 1-D fraction of the ideal rectangle aperture spectrum energy inside
% |f| <= F. The full-line denominator is analytic (integral of sinc^2 is 1/W);
% the numerator is an adaptive quadrature over [0,W*F], so this is not a
% finite-window truncation of the spectrum.
a=W*F;
if ~isfinite(a) || a<=0
    p=0;
    return;
end
% Integrate one unit interval at a time so the adaptive quadrature never has
% to resolve many sinc^2 oscillations in a single call.
nIntervals=ceil(a);
numerator=0;
for k=0:nIntervals-1
    lo=k;
    hi=min(k+1,a);
    numerator=numerator+integral(@(u) local_sinc(u).^2,lo,hi, ...
        'AbsTol',1e-13,'RelTol',1e-12);
    if hi>=a, break; end
end
p=2*numerator; % the full-line denominator is 1 after normalization by 1/W
p=min(1,max(0,p));
end
