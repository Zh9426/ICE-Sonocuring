function tests=test_integration
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'simulation'),fullfile(root,'config'),fullfile(root,'scripts'));
t.TestData.root=root;
end
function testSmallEndToEndAndSharedReference(t)
c=small_config('linear');r=ice.simulate(c);
verifySize(t,r.pressure_pa,[441 1]);
verifyGreaterThan(t,r.reference.pressure_peak_pa,0);
verifyGreaterThanOrEqual(t,r.metrics.target_coverage,0);
verifyLessThanOrEqual(t,r.metrics.target_coverage,1);
c.architecture.type='partitioned';q=ice.simulate(c,r.reference);
verifyEqual(t,q.reference,r.reference);
verifyLessThan(t,q.drive.active_elements,r.drive.active_elements);
end
function testFocusGainAndSymmetry(t)
c=small_config('linear');g=ice.make_geometry(c.array);
s=ice.make_sequence(g,true(prod(c.array.size),1),c);
p=ice.solve_pressure(g,s.shots,[0 0 .015;0 .003 .015;0 -.003 .015],c);
c.excitation.mode='broad';b=ice.make_sequence(g,true(prod(c.array.size),1),c);
pb=ice.solve_pressure(g,b.shots,[0 0 .015],c);
verifyGreaterThan(t,abs(p(1)),abs(pb));
verifyEqual(t,p(2),p(3),'AbsTol',1e-10);
end
function testExpandedSeparateShotCount(t)
c=small_config('matrix');c.excitation.mode='expanded';r=ice.simulate(c);
verifySize(t,r.pressure_pa,[441 3]);
expected=abs(r.pressure_pa).^2*r.sequence.dwell_weights(:)/(2*1000*1500)*.2;
verifyEqual(t,r.exposure.intensity_temporal_average_w_m2,expected,'AbsTol',1e-12);
end
function testMatrixElevationSteering(t)
c=small_config('matrix');c.excitation.focus_m=[0 .003 .015];
g=ice.make_geometry(c.array);s=ice.make_sequence(g,true(size(g.positions_m,1),1),c);
p=ice.solve_pressure(g,s.shots,[0 .003 .015;0 -.003 .015],c);
verifyGreaterThan(t,abs(p(1)),abs(p(2))*1.2);
end
function testSweepExportsCommonReference(t)
c=small_config('linear');out=fullfile(t.TestData.root,'results','validation','sweep_smoke');
summary=run_parameter_sweep(c,'acoustics.frequency_hz',[2e6 3e6],out);
verifyEqual(t,height(summary),2);
verifyEqual(t,summary.reference_pressure_pa(1),summary.reference_pressure_pa(2));
verifyTrue(t,isfile(fullfile(out,'sweep.csv')));
end
function testSubapertureSuperpositionAndZeroSource(t)
c=small_config('linear');g=ice.make_geometry(c.array);n=size(g.positions_m,1);
s=ice.make_sequence(g,true(n,1),c);q=[0 0 .015;.001 .002 .016];
full=ice.solve_pressure(g,s.shots,q,c);
a=s.shots;b=s.shots;a.weights(2:2:end)=0;b.weights(1:2:end)=0;
pa=ice.solve_pressure(g,a,q,c);pb=ice.solve_pressure(g,b,q,c);
verifyEqual(t,pa+pb,full,'AbsTol',1e-10);
c.source.velocity_m_s=0;p=ice.solve_pressure(g,s.shots,q,c);
verifyEqual(t,abs(p),zeros(2,1));
end
function c=small_config(kind)
c=demo_config(kind);if strcmp(kind,'linear'),c.array.size=[16 1];else,c.array.size=[6 6];end
c.grid.x_m=linspace(-.003,.003,9);c.grid.y_m=linspace(-.002,.002,7);c.grid.z_m=linspace(.012,.018,7);
c.solver.patch_count=[2 4];
end
