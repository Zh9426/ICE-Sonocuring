function tests = test_drive_limits
tests = functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'simulation'),fullfile(root,'config'));
end

function testUnknownPassFailAndUnits(t)
c=demo_config('linear');c.array.size=[4 1];
g=ice.make_geometry(c.array);
s=ice.make_sequence(g,true(4,1),c);
f=ice.check_drive_limits(c,g,s);
verifyEqual(t,f.status,'unknown');
c.hardware=struct('max_element_velocity_m_s',.02, ...
    'max_duty_cycle',.3,'max_exposure_time_s',2, ...
    'max_total_channels',4,'max_curing_channels',4);
f=ice.check_drive_limits(c,g,s);
verifyEqual(t,f.status,'pass');
verifyEqual(t,f.observed.max_element_velocity_m_s,.01,'AbsTol',1e-12);
verifyEqual(t,f.observed.total_channels,4);
c.hardware.max_element_velocity_m_s=.005;
f=ice.check_drive_limits(c,g,s);
verifyEqual(t,f.status,'fail');
verifyTrue(t,any(strcmp(f.failed_limits,'max_element_velocity_m_s')));
c.hardware.max_element_velocity_m_s=.02;c.hardware.max_total_channels=3;
f=ice.check_drive_limits(c,g,s);
verifyEqual(t,f.status,'fail');
verifyTrue(t,any(strcmp(f.failed_limits,'max_total_channels')));
end

function testInvalidLimitRejected(t)
c=demo_config('linear');c.array.size=[4 1];
g=ice.make_geometry(c.array);s=ice.make_sequence(g,true(4,1),c);
c.hardware.max_element_velocity_m_s=-1;
verifyError(t,@() ice.check_drive_limits(c,g,s),'ice:HardwareLimits');
end
