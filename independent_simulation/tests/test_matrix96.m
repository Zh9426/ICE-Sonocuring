function tests=test_matrix96
tests=functiontests(localfunctions);
end
function testGeometryAndPartition(t)
c=iceind.matrix96_config; a=iceind.matrix96_model(c,'left'); b=iceind.matrix96_model(c,'right');
verifySize(t,a.positions_m,[96 3]);
verifyEqual(t,size(unique(a.positions_m,'rows'),1),96);
verifyEqual(t,numel(unique(a.positions_m(:,1))),12);
verifyEqual(t,numel(unique(a.positions_m(:,2))),8);
verifyEqual(t,sum(a.active),48); verifyEqual(t,sum(b.active),48);
verifyFalse(t,any(a.active & b.active)); verifyTrue(t,all(a.active | b.active));
end
function testFocusArrivalAndMirror(t)
c=iceind.matrix96_config; a=iceind.matrix96_model(c,'left'); b=iceind.matrix96_model(c,'right');
travel=vecnorm(a.positions_m-c.focus_m,2,2)/c.sound_speed_m_s;
arrival=travel(a.active)+a.delay_s(a.active);
verifyLessThan(t,max(arrival)-min(arrival),1e-13);
verifyEqual(t,sort(a.delay_s(a.active)),sort(b.delay_s(b.active)),'AbsTol',1e-13);
end
function testOverlapRejected(t)
c=iceind.matrix96_config; c.element_size_m=c.pitch_m*1.1;
verifyError(t,@()iceind.matrix96_model(c,'left'),'iceind:MatrixGeometry');
end
function testAreaAndYLocations(t)
c=iceind.matrix96_config; a=iceind.matrix96_model(c,'left');
v=(-50:50)'*64e-6;
w=iceind.matrix96_weights(v,v,64e-6,a.positions_m,c.element_size_m);
verifyEqual(t,sum(double(w),1)*(64e-6)^2,repmat(prod(c.element_size_m),1,96),'RelTol',1e-6);
[~,i1]=max(w(:,1));[~,i2]=max(w(:,13));
verifyNotEqual(t,i1,i2);
end
