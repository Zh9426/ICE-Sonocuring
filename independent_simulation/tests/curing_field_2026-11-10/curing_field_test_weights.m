function tests=curing_field_test_weights
tests=functiontests(localfunctions);
end
function setupOnce(t)
td=fileparts(mfilename('fullpath')); root=fileparts(fileparts(td));
addpath(root); addpath(td); t.TestData.root=root;
end
function testAreaIsConservedOnBothGrids(t)
c=iceind.curing_field_cases();
pos=((-(64-1)/2):((64-1)/2))'*0.13e-3;
for k=[1 4]
    n=round(c(k).domain_m/c(k).dx_m);
    kg=kWaveGrid(n(1),c(k).dx_m,n(2),c(k).dx_m,n(3),c(k).dx_m);
    [w,wx,wy]=iceind.curing_field_weights(kg.x_vec,kg.y_vec,c(k).dx_m,pos,0.11e-3,2.02e-3);
    verifyEqual(t,size(w),[prod(n(1:2)) numel(pos)]);
    verifyLessThan(t,max(abs(sum(double(w),1)*c(k).dx_m^2-0.11e-3*2.02e-3)),1e-12);
    verifyLessThan(t,max(abs(sum(wx,1)*c(k).dx_m-0.11e-3)),1e-12);
    verifyLessThan(t,max(abs(sum(wy,1)*c(k).dx_m-2.02e-3)),1e-12);
    verifyTrue(t,all(w(:)>=0 & w(:)<=1));
end
end
function testAdjacentElementsDoNotOverlapAtNominalPitch(t)
% Rectangles are physically disjoint, but adjacent rectangles can share a
% grid cell. Their fractional coverage of a cell cannot exceed one.
c=iceind.curing_field_cases();
pos=((-(64-1)/2):((64-1)/2))'*0.13e-3;
for k=[1 4]
    n=round(c(k).domain_m/c(k).dx_m);
    kg=kWaveGrid(n(1),c(k).dx_m,n(2),c(k).dx_m,n(3),c(k).dx_m);
    [~,wx]=iceind.curing_field_weights(kg.x_vec,kg.y_vec,c(k).dx_m,pos,0.11e-3,2.02e-3);
    verifyLessThanOrEqual(t,max(sum(wx,2)),1+1e-10);
end
end
function testAlignedRectangleMomentsConvergeWithCells(t)
dx=65e-6; axis_vec=((-(40):(39))*dx)';
s2=iceind.curing_field_representation(axis_vec,box_frac(axis_vec,dx,2*dx),dx,2*dx);
s10=iceind.curing_field_representation(axis_vec,box_frac(axis_vec,dx,10*dx),dx,10*dx);
verifyLessThan(t,abs(s2.area_relative_error),1e-12);
verifyLessThan(t,abs(s10.area_relative_error),1e-12);
verifyLessThan(t,abs(s10.effective_width_relative_error),0.02);
verifyGreaterThan(t,abs(s2.effective_width_relative_error),abs(s10.effective_width_relative_error));
end
function testElementWidthRepresentationWorsensOnCoarseGrid(t)
c=iceind.curing_field_cases();
n65=round(c(1).domain_m/c(1).dx_m); n52=round(c(3).domain_m/c(3).dx_m);
kg65=kWaveGrid(n65(1),c(1).dx_m,n65(2),c(1).dx_m,n65(3),c(1).dx_m);
kg52=kWaveGrid(n52(1),c(3).dx_m,n52(2),c(3).dx_m,n52(3),c(3).dx_m);
[~,wx65]=iceind.curing_field_weights(kg65.x_vec,kg65.y_vec,c(1).dx_m,0,0.11e-3,2.02e-3);
[~,wx52]=iceind.curing_field_weights(kg52.x_vec,kg52.y_vec,c(3).dx_m,0,0.11e-3,2.02e-3);
a=iceind.curing_field_representation(kg65.x_vec,wx65,c(1).dx_m,0.11e-3);
b=iceind.curing_field_representation(kg52.x_vec,wx52,c(3).dx_m,0.11e-3);
verifyLessThan(t,abs(a.area_relative_error),1e-12);
verifyLessThan(t,abs(b.area_relative_error),1e-12);
verifyLessThan(t,abs(b.effective_width_relative_error),abs(a.effective_width_relative_error));
verifyLessThan(t,a.spectrum_l2_relative_error,0.3);
verifyLessThan(t,b.spectrum_l2_relative_error,0.3);
end
function frac=box_frac(axis_vec,dx,w)
lo=-w/2; hi=w/2;
frac=max(0,min(axis_vec+dx/2,hi)-max(axis_vec-dx/2,lo))/dx;
end
