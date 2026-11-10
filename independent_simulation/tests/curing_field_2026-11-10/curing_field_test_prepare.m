function tests=curing_field_test_prepare
tests=functiontests(localfunctions);
end
function setupOnce(t)
td=fileparts(mfilename('fullpath')); root=fileparts(fileparts(td));
addpath(root); addpath(td);
kw=fullfile(root,'dependencies','k-wave-1.4.1','k-Wave');
if ~isfolder(kw), kw=fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'); end
addpath(kw);
t.TestData.root=root;
end
function testMockAll64CoarseGeometryAndTimeWindow(t)
c=iceind.curing_field_cases(); c=c(1);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
s=curing_field_mock_driver(c.ranks); save(f,'-struct','s');
[kg,medium,source,sensor,m,wave]=iceind.curing_field_prepare(c,f);
verifyEqual(t,m.num_active,64);
verifyEqual(t,m.source_ranks,1:64);
verifyLessThan(t,m.area_error_m2,1e-12);
verifyEqual(t,m.grid_size,[240 160 480]);
verifyEqual(t,numel(kg.t_array),m.Nt);
verifyGreaterThanOrEqual(t,m.t_end_s,40e-6);
verifyLessThanOrEqual(t,size(source.p,2),m.Nt);
verifyGreaterThan(t,nnz(source.p_mask),0);
verifyLessThan(t,nnz(source.p_mask),prod(m.grid_size(1:2)));
verifyTrue(t,all(sensor.mask(:)));
verifyEqual(t,m.target_m,[0 0 20]*1e-3,'AbsTol',1e-15);
verifyEqual(t,medium.sound_speed,1540);
verifyEqual(t,medium.density,1000);
verifyTrue(t,m.equal_signal_scale_across_elements);
verifyLessThan(t,m.per_element_peak_sample_spread_relative,0.05);
verifyLessThan(t,m.active_center_arrival_spread_s,1e-12);
verifyEqual(t,sum(m.per_element_proxy_pa2_s_m2),m.source_proxy_total_pa2_s_m2,'RelTol',1e-12);
verifyEqual(t,size(wave,1),64);
end
function testMockCenter16FineGrid(t)
c=iceind.curing_field_cases(); c=c(4);
f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
s=curing_field_mock_driver(c.ranks); save(f,'-struct','s');
[kg,~,source,~,m]=iceind.curing_field_prepare(c,f);
verifyEqual(t,m.num_active,16);
verifyEqual(t,m.source_ranks,25:40);
verifyEqual(t,m.grid_size,[300 200 600]);
verifyLessThan(t,m.area_error_m2,1e-12);
verifyLessThanOrEqual(t,size(source.p,2),m.Nt);
verifyGreaterThan(t,m.f_number_target_over_span,9);
verifyLessThan(t,m.fill_fraction_of_span,1);
end
function testAreaErrorIsReportedPerGrid(t)
c=iceind.curing_field_cases();
for k=[1 4]
    f=[tempname '.mat']; cleanup=onCleanup(@()delete_if(f));
    s=curing_field_mock_driver(c(k).ranks); save(f,'-struct','s');
    [~,~,~,~,m]=iceind.curing_field_prepare(c(k),f);
    verifyLessThan(t,m.area_error_m2,1e-12);
    verifyEqual(t,m.case_tag,c(k).tag);
    verifyGreaterThan(t,m.source_proxy_total_pa2_s_m2,0);
end
end
function delete_if(f)
if isfile(f), delete(f); end
end
