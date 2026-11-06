function m=matrix96_model(c,part)
%MATRIX96_MODEL Fixed spatial groups, no time-switching or hardware commands.
assert(isequal(c.layout,[12 8]) && all(isfinite(c.pitch_m)) && ...
    all(c.pitch_m>0) && all(c.element_size_m>0) && ...
    all(c.element_size_m<=c.pitch_m),'iceind:MatrixGeometry','Invalid matrix geometry.');
assert(numel(c.focus_m)==3 && all(isfinite(c.focus_m)) && c.focus_m(3)>0, ...
    'iceind:Focus','Focus must be finite and in front of array.');
[x,y]=ndgrid(((1:12)-6.5)*c.pitch_m(1),((1:8)-4.5)*c.pitch_m(2));
m.positions_m=[x(:),y(:),zeros(96,1)];
switch part
    case 'left', m.active=x(:)<0;
    case 'right',m.active=x(:)>0;
    case 'bottom',m.active=y(:)<0;
    case 'top',m.active=y(:)>0;
    case 'full_reference',m.active=true(96,1);
    otherwise,error('iceind:Partition','Unknown fixed partition.');
end
d=vecnorm(m.positions_m-c.focus_m,2,2);
m.delay_s=zeros(96,1);
m.delay_s(m.active)=(max(d(m.active))-d(m.active))/c.sound_speed_m_s;
m.partition=part; m.element_id=(1:96)';
end
