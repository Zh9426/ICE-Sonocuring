function curing_multifocus_audit_20261114()
% Read back solver HDF5 independently from the saved MAT arrays.
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'results','multifocus_2026-11-14');
rows=struct('variant',{},'dx_um',{},'p_amp_equal',{},'qp_equal',{},'p_final_equal',{}); nrow=0;
for dx=[65 52]
    for variant={'baseline','dual','quad'}
        tag=sprintf('%s_dx%d',variant{1},dx);
        file=fullfile(folder,[tag '_field.mat']);
        if ~isfile(file), continue; end
        s=load(file,'p_amp','qp','p_final','Nt','dt_s');
        n=size(s.p_amp); run=fullfile(folder,[tag '_gpu_io']);
        input=fullfile(run,'field_input.h5'); output=fullfile(run,'field_output.h5');
        shape=double([h5read(input,'/Nx') h5read(input,'/Ny') h5read(input,'/Nz')]);
        pml=double([h5read(input,'/pml_x_size') h5read(input,'/pml_y_size') h5read(input,'/pml_z_size')]);
        assert(isequal(n+2*pml,shape) && h5read(input,'/Nt')==s.Nt);
        start=pml+1;
        p=isequal(s.p_amp,max(h5read(output,'/p_max_all',start,n),-h5read(output,'/p_min_all',start,n)));
        r=h5read(output,'/p_rms');
        q=isequal(s.qp,reshape(single(double(r).^2*double(s.Nt)*s.dt_s),n));
        final=isequal(s.p_final,h5read(output,'/p_final',start,n));
        assert(p && q && final,'Field MAT and raw output differ.');
        nrow=nrow+1; rows(nrow)=struct('variant',variant{1},'dx_um',dx, ...
            'p_amp_equal',p,'qp_equal',q,'p_final_equal',final);
        fprintf('%s raw HDF5 readback passed\n',tag);
        clear s r
    end
end
writetable(struct2table(rows),fullfile(folder,'hdf5_readback.csv'));
end
