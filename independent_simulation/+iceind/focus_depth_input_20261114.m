function s=focus_depth_input_20261114(base,depth_mm)
% Synthetic simulation input derived from the All64 export; not a hardware sequence.
assert(ismember(depth_mm,[16 18 20 22]));
s=base; b=iceind.compile_kwave(base);
assert(numel(b.tx)==1 && all(b.tx.apod==1));
d=vecnorm(b.geometry.positions_m-[0 0 depth_mm*1e-3],2,2);
delay=(max(d)-d)/b.sound_speed_m_s;
s.TX.Delay=delay'*(double(s.Trans.frequency)*1e6);
s.synthetic_focus_depth_mm=depth_mm;
end
