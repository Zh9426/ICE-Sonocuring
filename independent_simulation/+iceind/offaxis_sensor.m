function [sensor,m]=offaxis_sensor(kg,sourceZ)
%OFFAXIS_SENSOR Sparse traces with explicit label-to-k-Wave row mapping.
labels={'target','near_main','qp_main','offaxis_pos','offaxis_neg', ...
 'offaxis_pos_z1','offaxis_neg_z1','offaxis_pos_z3','offaxis_pos_z5', ...
 'near_source_peak','axis_z2','axis_z5'};
requested=[0 0 20;0 0 18.395;0 0 18.33;6.37 0 2.015;-6.37 0 2.015; ...
 6.37 0 1.04;-6.37 0 1.04;6.37 0 3.055;6.37 0 5.005; ...
 1.82 .52 .13;0 0 2.015;0 0 5.005]*1e-3;
n=[kg.Nx kg.Ny kg.Nz]; sensor.mask=false(n);
linear=zeros(numel(labels),1); actual=zeros(size(requested));
for j=1:numel(labels)
 [~,a]=min(abs(kg.x_vec-requested(j,1)));
 [~,b]=min(abs(kg.y_vec-requested(j,2)));
 [~,c]=min(abs(kg.z_vec-sourceZ-requested(j,3)));
 actual(j,:)=[kg.x_vec(a) kg.y_vec(b) kg.z_vec(c)-sourceZ];
 linear(j)=sub2ind(n,a,b,c); sensor.mask(linear(j))=true;
end
assert(max(abs(actual-requested),[],'all')<=kg.dx/2+1e-12, ...
 'iceind:TraceROI','A requested sensor lies outside the physical grid.');
[present,row]=ismember(linear,find(sensor.mask)); assert(all(present));
sensor.record={'p','p_rms','p_max_all','p_min_all'}; sensor.record_start_index=1;
m=struct('labels',{labels},'requested_xyz_m',requested,'actual_xyz_m',actual, ...
 'linear_indices',linear,'trace_row',row,'ordering','Rows of p follow find(sensor.mask), not label order.');
end
