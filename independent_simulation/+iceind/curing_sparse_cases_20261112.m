function cases=curing_sparse_cases_20261112()
% Four interleaved physical-x-rank cases, same reference grid and medium.
base=iceind.curing_field_cases(true); cases=base([]);
for dx=[65 52]
    ref=base(find(strcmp({base.variant},'All64') & abs([base.dx_m]-dx*1e-6)<1e-12,1));
    for k=1:2
        c=ref;
        if k==1, c.variant='Odd32'; c.ranks=1:2:63;
        else, c.variant='Even32'; c.ranks=2:2:64; end
        c.num_active=32; c.entry='SetUpICE_CuringOnly (custom physical ranks)';
        c.tag=sprintf('%s_dx%dum',lower(c.variant),dx);
        cases(end+1)=c; %#ok<AGROW>
    end
end
end
