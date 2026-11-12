function cases=curing_field_cases(includeAll)
%CURING_FIELD_CASES Default two variants; includeAll=true selects all four.
% One physical domain and the same PML thickness (1.04 mm) are kept so that
% the only grid change is dx. Each active element receives the SAME assumed
% source signal (1 Pa reference); there is no cross-grid or cross-aperture
% budget matching. Per-element delays come from the user's exported TX.
root=fileparts(fileparts(mfilename('fullpath')));
out=fullfile(root,'results','curing_field_2026-11-10');
variants=iceind.curing_field_variants();
if nargin<1, includeAll=false; end
if includeAll, keep=1:4; else, keep=[1 4]; end
grids=[65e-6 52e-6];
cases=struct('tag',{},'variant',{},'entry',{},'ranks',{},'num_active',{}, ...
    'dx_m',{},'domain_m',{},'pml_m',{},'cfl',{},'density_kg_m3',{}, ...
    'sound_speed_m_s',{},'source_offset_m',{},'source_amplitude_pa',{}, ...
    'minimum_end_time_s',{},'output_dir',{},'provenance',{});
for gi=1:numel(grids)
    for vi=keep
        v=variants(vi);
        c=struct();
        c.tag=sprintf('%s_dx%02dum',lower(v.name),round(grids(gi)*1e6));
        c.variant=v.name;
        c.entry=v.entry;
        c.ranks=v.ranks;
        c.num_active=v.num_active;
        c.dx_m=grids(gi);
        c.domain_m=[15.6 10.4 31.2]*1e-3;
        c.pml_m=1.04e-3;
        c.cfl=0.2;
        c.density_kg_m3=1000;
        c.sound_speed_m_s=1540;
        c.source_offset_m=0.52e-3;
        c.source_amplitude_pa=1;
        c.minimum_end_time_s=40e-6;
        c.output_dir=out;
        c.provenance=['assumed_homogeneous_lossless_linear_flat_rectangles; ' ...
            'equal_assumed_source_per_element_not_energy_calibrated'];
        cases(end+1)=c; %#ok<AGROW>
    end
end
end
