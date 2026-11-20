function test_steered_focus_recovery_20261120()
% Verify recovery conversion against an already completed field, without overwrite.
root=fileparts(mfilename('fullpath')); addpath(root);
report=curing_steered_focus_recover_20261120(20,true);
assert(report.existing_field_verified && report.completed_steps==report.Nt);
assert(report.pressure_equal && report.qp_equal && report.final_equal && report.axes_equal);
disp('PASS: raw-HDF5 recovery matches completed +20 deg field, Qp, final frame and axes.');
end
