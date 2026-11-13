function tests=curing_field_test_sparse_cases
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(root); t.TestData.root=root;
end
function testSparseCasesAndReferenceAssumptions(t)
c=iceind.curing_sparse_cases_20261112(); ref=iceind.curing_field_cases(true);
verifyEqual(t,numel(c),4);
verifyEqual(t,{c.variant},{'Odd32','Even32','Odd32','Even32'});
verifyEqual(t,c(1).ranks,1:2:63); verifyEqual(t,c(2).ranks,2:2:64);
verifyEqual(t,[c.num_active],[32 32 32 32]);
verifyEqual(t,[c.dx_m],[65 65 52 52]*1e-6,'AbsTol',1e-18);
for k=1:4
    refcase=ref(find(strcmp({ref.variant},'All64') & abs([ref.dx_m]-c(k).dx_m)<1e-12,1));
    for field={'domain_m','pml_m','cfl','density_kg_m3','sound_speed_m_s', ...
            'source_offset_m','source_amplitude_pa','minimum_end_time_s'}
        verifyEqual(t,c(k).(field{1}),refcase.(field{1}));
    end
end
end
function testSavedSparseExportsAgainstAll64(t)
root=t.TestData.root; folder=fullfile(root,'results','curing_sparse_2026-11-12','drivers');
manifest=jsondecode(fileread(fullfile(folder,'sparse_manifest.json')));
ref=load(fullfile(root,'results','curing_export_2026-11-10', ...
    'ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat'));
b0=iceind.compile_kwave(ref); cases=iceind.curing_sparse_cases_20261112();
for k=1:2
    file=fullfile(folder,manifest.rows(k).file); s=load(file); b=iceind.compile_kwave(s); ranks=cases(k).ranks;
    verifyEqual(t,iceind.curing_field_sha256(file),manifest.rows(k).sha256);
    verifyEqual(t,find(b.tx.apod~=0),ranks);
    verifyEqual(t,b.tx.delay_s(ranks),b0.tx.delay_s(ranks),'AbsTol',1e-15);
    verifyEqual(t,b.geometry.positions_m,b0.geometry.positions_m,'AbsTol',1e-15);
    verifyEqual(t,s.TW,ref.TW); verifyEqual(t,s.Resource.Parameters.speedOfSound,ref.Resource.Parameters.speedOfSound);
    verifyEqual(t,s.ICEConfig.exposure.foci_mm,[0 0 20]);
end
end
