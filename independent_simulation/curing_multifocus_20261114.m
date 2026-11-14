function curing_multifocus_20261114()
% Offline simulation inputs. Synthetic positions, no hardware authorization.
root=fileparts(mfilename('fullpath')); addpath(root);
out=fullfile(root,'results','multifocus_2026-11-14');
if ~isfolder(out), mkdir(out); end
base=fullfile(root,'results','curing_export_2026-11-10','ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat');
for groups=[2 4]
    s=load(base); b=iceind.compile_kwave(s);
    [~,order]=sort(b.geometry.positions_m(:,1));
    focusX=linspace(-2,2,groups);
    if groups==4, focusX=[-3 -1 1 3]; end
    distances=zeros(1,64);
    for k=1:groups
        idx=order((k-1)*64/groups+1:k*64/groups);
        target=[focusX(k) 0 20]*1e-3;
        distances(idx)=vecnorm(b.geometry.positions_m(idx,:)-target,2,2);
    end
    delay=(max(distances)-distances)/b.sound_speed_m_s;
    assert(all(delay>=0) && numel(unique(order))==64);
    for k=1:groups
        idx=order((k-1)*64/groups+1:k*64/groups);
        arrival=delay(idx)+distances(idx)/b.sound_speed_m_s;
        assert(max(arrival)-min(arrival)<1e-12);
    end
    s.TX.Delay=delay*(double(s.Trans.frequency)*1e6);
    s.TX.focus=0; s.TX.FocalPt=[]; s.TX.Steer=[0 0];
    s.multifocus_assumption=struct('focus_x_mm',focusX,'focus_depth_mm',20, ...
        'physical_order',order,'delay_s',delay,'label','synthetic offline simulation input, not a hardware sequence');
    if groups==2, name='dual'; else, name='quad'; end
    inputFile=fullfile(out,[name '_simulation_input.mat']);
    if isfile(inputFile)
        prior=load(inputFile,'multifocus_assumption','TX');
        assert(isequaln(prior.multifocus_assumption,s.multifocus_assumption) && ...
            isequaln(prior.TX,s.TX),'Existing input differs; choose a new output directory.');
    else
        save(inputFile,'-struct','s');
    end
end
for dx=[65 52]
    for name={'Dual','Quad'}
        raw=fullfile(out,sprintf('%s_dx%d_field.mat',lower(name{1}),dx));
        if isfile(raw)
            fprintf('Using existing field %s\n',raw);
        else
            raw=curing_multifocus_gpu_20261114(name{1},dx);
            fprintf('Completed %s\n',raw);
        end
    end
end
end
