function tests = test_verasonics_probe
% Pure geometry/math tests; no VSX, activation, or hardware calls.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
addpath(fullfile(root, 'verasonics', 'dual_mode'));
testCase.TestData.vendorUtilities = fullfile(root, 'VantageNXT-2.3.2-p2', 'Utilities');
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function testBaselineProbeGeometryAndUnits(testCase)
p = baseline_probe();
t = icevs.make_trans(p, 1540);
scale = p.frequency_mhz / 1.540;
verifyEqual(testCase, t.name, 'P9-4ULts');
verifyEqual(testCase, t.numelements, 64);
verifyEqual(testCase, t.units, 'wavelengths');
verifyEqual(testCase, t.type, 0);
verifyEqual(testCase, t.frequency, 6.5);
verifyEqual(testCase, t.Bandwidth, [4 9]);
verifyEqual(testCase, t.connType, 4);
verifyEqual(testCase, t.ConnectorES, (1:64)');
verifySize(testCase, t.ElementPos, [64 5]);
verifyEqual(testCase, t.ElementPos(:,1), ((-31.5:31.5)' * .13) * scale, 'AbsTol', 1e-12);
verifyEqual(testCase, t.ElementPos(:,2:5), zeros(64,4));
verifyEqual(testCase, t.spacingMm, .13);
verifyEqual(testCase, t.spacing, .13 * scale, 'AbsTol', 1e-12);
verifyEqual(testCase, t.elementWidth, .11 * scale, 'AbsTol', 1e-12);
verifyEqual(testCase, t.elevationApertureMm, 2.02);
verifyEqual(testCase, t.elevationFocusMm, 30);
verifyEqual(testCase, t.lensCorrection, 0);
verifyEqual(testCase, t.impedance, 50);
verifyEqual(testCase, t.maxHighVoltage, 35);
verifyEqual(testCase, t.id, -1);
verifySize(testCase, t.ElementSens, [1 101]);
verifyTrue(testCase, all(isfinite(t.ElementSens)));
verifyEqual(testCase, t.ElementSens, fliplr(t.ElementSens), 'AbsTol', 1e-12);
verifyEqual(testCase, t.ElementSens(51), 1, 'AbsTol', 1e-12);
end

function testExplicit96GeometryAndMapping(testCase)
p = baseline_probe();
p.num_elements = 96;
verifyError(testCase, @() icevs.make_trans(p, 1540), 'icevs:Probe');
p.connector_es = (96:-1:1)';
p.pitch_mm = .2;
p.width_mm = .15;
p.positions_mm = [(-47.5:47.5)'*.2 + .7, zeros(96,2)];
p.lens_correction_mm = .4;
t = icevs.make_trans(p, 1500);
verifyEqual(testCase, t.numelements, 96);
verifyEqual(testCase, t.ConnectorES, (96:-1:1)');
verifyEqual(testCase, t.ElementPos(:,1:3), p.positions_mm * 6.5/1.5, 'AbsTol', 1e-12);
verifyEqual(testCase, t.lensCorrection, .4*6.5/1.5, 'AbsTol', 1e-12);
p.positions_mm = [];
t = icevs.make_trans(p, 1500);
verifySize(testCase, t.ElementPos, [96 5]);
verifyEqual(testCase, mean(t.ElementPos(:,1)), 0, 'AbsTol', 1e-12);
end

function testProbeRejectsInvalidScalarsAndBandwidth(testCase)
p = baseline_probe();
fields = {'num_elements','frequency_mhz','pitch_mm','width_mm', ...
    'elevation_aperture_mm','elevation_focus_mm','impedance_ohm','max_high_voltage_v'};
for k = 1:numel(fields)
    bad = p; bad.(fields{k}) = NaN;
    verifyError(testCase, @() icevs.make_trans(bad,1540), 'icevs:Probe');
    bad.(fields{k}) = 0;
    verifyError(testCase, @() icevs.make_trans(bad,1540), 'icevs:Probe');
end
p.num_elements = 64.5;
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
p = baseline_probe(); p.width_mm = 2*p.pitch_mm;
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
p = baseline_probe(); p.bandwidth_mhz = [9 4];
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
p.bandwidth_mhz = [4 Inf];
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
p = baseline_probe();
verifyError(testCase, @() icevs.make_trans(p,NaN), 'icevs:Probe');
verifyError(testCase, @() icevs.make_trans(p,0), 'icevs:Probe');
end

function testProbeRejectsInvalidCoordinatesAndMapping(testCase)
p = baseline_probe(); p.positions_mm = zeros(63,3);
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
p.positions_mm = [(-31.5:31.5)'*.13, zeros(64,2)];
for k = 2:3
    bad = p; bad.positions_mm(1,k) = .1;
    verifyError(testCase, @() icevs.make_trans(bad,1540), 'icevs:Probe');
end
p.positions_mm(1,1) = Inf;
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
p = baseline_probe();
for value = [0 1.5 NaN Inf]
    bad = p; bad.connector_es(3) = value;
    verifyError(testCase, @() icevs.make_trans(bad,1540), 'icevs:Probe');
end
p.connector_es(3) = p.connector_es(2);
verifyError(testCase, @() icevs.make_trans(p,1540), 'icevs:Probe');
end

function testFocusedArrivalsCoincideAndAreSymmetric(testCase)
t = icevs.make_trans(baseline_probe(),1540);
[delay, focal] = icevs.tx_delays(t, 80, [0 0], ones(1,64));
distance = sqrt(sum((t.ElementPos(:,1:3)-focal).^2,2))';
verifyEqual(testCase, delay + distance, repmat(max(distance),1,64), 'AbsTol',1e-12);
verifyEqual(testCase, delay, fliplr(delay), 'AbsTol',1e-12);
verifyEqual(testCase, min(delay), 0);
verifyEqual(testCase, focal, [0 0 80]);
end

function testSteeredFocusAndActiveAperture(testCase)
t = icevs.make_trans(baseline_probe(),1540);
apod = zeros(64,1); apod(5:47) = 1;
[delay, focal] = icevs.tx_delays(t, 90, [.3 0], apod, [2 0 0]);
active = apod' ~= 0;
distance = sqrt(sum((t.ElementPos(:,1:3)-focal).^2,2))';
verifySize(testCase, delay, [1 64]);
verifyEqual(testCase, delay(~active), zeros(1,nnz(~active)));
verifyEqual(testCase, delay(active)+distance(active), ...
    repmat(max(distance(active)),1,nnz(active)), 'AbsTol',1e-12);
verifyEqual(testCase, min(delay(active)), 0);
verifyGreaterThan(testCase, max(delay(active)), 1);
verifyEqual(testCase, focal, [2+90*sin(.3),0,90*cos(.3)], 'AbsTol',1e-12);
end

function testDivergingAndPlaneWaveSign(testCase)
t = icevs.make_trans(baseline_probe(),1540);
[delay, focal] = icevs.tx_delays(t, -20, [.4 0], ones(1,64));
distance = sqrt(sum((t.ElementPos(:,1:3)-focal).^2,2))';
verifyEqual(testCase, distance-delay, repmat(min(distance),1,64), 'AbsTol',1e-12);
verifyLessThan(testCase, focal(3), 0);
[delay, focal] = icevs.tx_delays(t, 0, [.4 0], ones(1,64));
projection = t.ElementPos(:,1)' * sin(.4);
verifyEqual(testCase, delay, projection-min(projection), 'AbsTol',1e-12);
verifyEqual(testCase, focal, [0 0 0]);
verifyGreaterThan(testCase, delay(end), delay(1));
verifyEqual(testCase, icevs.tx_delays(t,0,[0 0],ones(1,64)), zeros(1,64));
end

function testDelayScalesInWavelengthsNotSeconds(testCase)
p = baseline_probe(); t1 = icevs.make_trans(p,1540);
p.frequency_mhz = 2*p.frequency_mhz;
p.bandwidth_mhz = 2*p.bandwidth_mhz;
t2 = icevs.make_trans(p,1540);
d1 = icevs.tx_delays(t1,80,[.1 0],ones(1,64));
d2 = icevs.tx_delays(t2,160,[.1 0],ones(1,64));
verifyEqual(testCase, d2, 2*d1, 'AbsTol',1e-12);
verifyEqual(testCase, d2/(t2.frequency*1e6), d1/(t1.frequency*1e6), 'AbsTol',1e-18);
end

function testDelayRejectsUnsupportedOrNonfiniteInputs(testCase)
t = icevs.make_trans(baseline_probe(),1540);
verifyError(testCase, @() icevs.tx_delays(t,80,[0 .1],ones(1,64)), 'icevs:Delays');
verifyError(testCase, @() icevs.tx_delays(t,80,[NaN 0],ones(1,64)), 'icevs:Delays');
verifyError(testCase, @() icevs.tx_delays(t,Inf,[0 0],ones(1,64)), 'icevs:Delays');
verifyError(testCase, @() icevs.tx_delays(t,80,[0 0],ones(1,63)), 'icevs:Delays');
verifyError(testCase, @() icevs.tx_delays(t,80,[0 0],zeros(1,64)), 'icevs:Delays');
badApod = ones(1,64); badApod(2) = NaN;
verifyError(testCase, @() icevs.tx_delays(t,80,[0 0],badApod), 'icevs:Delays');
for value = [-1 1.1]
    badApod = ones(1,64); badApod(2) = value;
    verifyError(testCase, @() icevs.tx_delays(t,80,[0 0],badApod), 'icevs:Delays');
end
verifyError(testCase, @() icevs.tx_delays(t,80,[0 0],ones(1,64),[NaN 0 0]), 'icevs:Delays');
verifyError(testCase, @() icevs.tx_delays(t,80,[0 0],ones(1,64),[0 1 0]), 'icevs:Delays');
bad = t; bad.type = 2;
verifyError(testCase, @() icevs.tx_delays(bad,80,[0 0],ones(1,64)), 'icevs:Delays');
bad = t; bad.ElementPos(2,1) = NaN;
verifyError(testCase, @() icevs.tx_delays(bad,80,[0 0],ones(1,64)), 'icevs:Delays');
bad = t; bad.units = 'mm';
verifyError(testCase, @() icevs.tx_delays(bad,80,[0 0],ones(1,64)), 'icevs:Delays');
bad = t; bad.HVMux = struct();
verifyError(testCase, @() icevs.tx_delays(bad,80,[0 0],ones(1,64)), 'icevs:Delays');
end

function testVendorDelayOracle(testCase)
% The oracle is an inspectable mathematical utility, never the VSX runtime.
utilities = testCase.TestData.vendorUtilities;
assumeTrue(testCase, isfile(fullfile(utilities,'computeTXDelays.m')), ...
    'Vendor utility is not installed; independent geometry tests remain available.');
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(utilities);
before = snapshot_base({'Trans','Resource'});
restoreBase = onCleanup(@() restore_base(before));
t = icevs.make_trans(baseline_probe(),1540);
assignin('base','Trans',t);
assignin('base','Resource',struct('Parameters',struct('speedOfSound',1540)));
for focus = [-20 0 80]
    for azimuth = [-.4 0 .3]
        apod = zeros(1,64); apod(3:59) = 1;
        tx = struct('focus',focus,'Steer',[azimuth 0],'Origin',[2 0 0],'Apod',apod);
        [referenceDelay,referenceFocal] = computeTXDelays(tx);
        [actualDelay,actualFocal] = icevs.tx_delays(t,focus,tx.Steer,apod,tx.Origin);
        verifyEqual(testCase, actualDelay, referenceDelay, 'AbsTol',1e-12);
        verifyEqual(testCase, actualFocal, referenceFocal, 'AbsTol',1e-12);
    end
end
end

function snapshot = snapshot_base(names)
snapshot = struct('name',names,'exists',false,'value',[]);
for k = 1:numel(names)
    snapshot(k).exists = evalin('base',sprintf('exist(''%s'',''var'') ~= 0',names{k}));
    if snapshot(k).exists
        snapshot(k).value = evalin('base',names{k});
    end
end
end

function restore_base(snapshot)
for k = 1:numel(snapshot)
    if snapshot(k).exists
        assignin('base',snapshot(k).name,snapshot(k).value);
    else
        evalin('base',['clear ' snapshot(k).name]);
    end
end
end

function p = baseline_probe()
% Existing code values; physical probe identity/calibration remain unknown.
p = struct('name','P9-4ULts','num_elements',64,'frequency_mhz',6.5, ...
    'bandwidth_mhz',[4 9],'pitch_mm',.13,'width_mm',.11, ...
    'elevation_aperture_mm',2.02,'elevation_focus_mm',30,'positions_mm',[], ...
    'connector_es',(1:64)','conn_type',4,'impedance_ohm',50, ...
    'max_high_voltage_v',35,'lens_correction_mm',0,'id',-1, ...
    'provenance','existing_code_unverified');
end
