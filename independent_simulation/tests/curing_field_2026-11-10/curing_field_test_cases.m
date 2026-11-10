function tests=curing_field_test_cases
tests=functiontests(localfunctions);
end
function setupOnce(t)
td=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(td));
addpath(root); addpath(td);
t.TestData.root=root;
end
function testFullPropagationBlockedUntilBliAndQpValidated(t)
verifyError(t,@()curing_field_run('run'),'iceind:CuringFieldNotReady');
verifyError(t,@()curing_field_run('all'),'iceind:CuringFieldNotReady');
end
function testFourCasesTwoVariantsTwoGrids(t)
c=iceind.curing_field_cases();
verifyEqual(t,numel(c),4);
verifyEqual(t,{c.variant},{'All64','Center16','All64','Center16'});
verifyEqual(t,[c.dx_m],[65e-6 65e-6 52e-6 52e-6],'AbsTol',1e-18);
verifyEqual(t,{c.tag},{'all64_dx65um','center16_dx65um','all64_dx52um','center16_dx52um'});
verifyEqual(t,[c.num_active],[64 16 64 16]);
end
function testGridsAndCommonDomain(t)
c=iceind.curing_field_cases();
expected=[240 160 480;300 200 600];
for k=1:4
    verifyEqual(t,c(k).domain_m,[15.6 10.4 31.2]*1e-3,'AbsTol',1e-15);
    verifyEqual(t,c(k).pml_m,1.04e-3,'AbsTol',1e-15);
    row=1+(c(k).dx_m<60e-6);
    verifyEqual(t,round(c(k).domain_m/c(k).dx_m),expected(row,:));
end
end
function testEqualSourceAssumptionIsRecorded(t)
c=iceind.curing_field_cases();
for k=1:4
    verifyEqual(t,c(k).source_amplitude_pa,1);
    verifyTrue(t,contains(c(k).provenance,'equal_assumed_source_per_element'));
end
end
function testVariantsMatchDocumentedEntries(t)
v=iceind.curing_field_variants();
verifyEqual(t,{v.name},{'All64','Center48','Center32','Center16'});
verifyEqual(t,v(1).ranks,1:64);
verifyEqual(t,v(2).ranks,9:56);
verifyEqual(t,v(3).ranks,17:48);
verifyEqual(t,v(4).ranks,25:40);
verifyEqual(t,{v.entry},{'SetUpICE_Curing_All64','SetUpICE_Curing_Center48', ...
    'SetUpICE_Curing_Center32','SetUpICE_Curing_Center16'});
end
