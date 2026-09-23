function summary = run_grating_demo(output_dir)
%RUN_GRATING_DEMO Periodic thinning creates a visible phase-repeat direction.
% Direction prediction applies to this regular 1-D steered aperture only.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
if nargin==0,output_dir=fullfile(root,'results','grating_demo');end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
cfg=demo_config('linear');cfg.excitation.mode='broad';cfg.excitation.steering_deg=[20 0];
g=ice.make_geometry(cfg.array);angles=(-85:.05:85)';lambda=cfg.acoustics.sound_speed_m_s/cfg.acoustics.frequency_hz;
labels={'shared','checkerboard'};curves=zeros(numel(angles),2);rows=cell(2,1);
fig=figure('Visible',cfg.output.visible,'Color','w','Position',[100 100 1100 520]);hold on;
for j=1:2
    candidate=cfg;
    if j==2,candidate.architecture.type='partitioned';candidate.architecture.pattern='checkerboard';end
    part=ice.partition_elements(g,candidate.architecture);seq=ice.make_sequence(g,part.curing_mask,candidate);
    response=ice.angular_response(g,seq.shots,angles,'xz',candidate);
    curves(:,j)=response.amplitude;
    plot(angles,20*log10(max(response.amplitude,1e-4)),'LineWidth',1.3,'DisplayName',labels{j});
    positions=sort(g.positions_m(abs(seq.shots.weights)>0,1));delta=diff(positions);
    if numel(delta)<1||max(abs(delta-delta(1)))>1e-9*delta(1)
        error('ice:NonperiodicAperture','This illustrative direction formula requires regular active x spacing.');
    end
    pitch=delta(1);orders=-ceil(2*pitch/lambda):ceil(2*pitch/lambda);
    u=sind(cfg.excitation.steering_deg(1))+orders*lambda/pitch;
    valid=abs(u)<1&orders~=0;predicted=asind(u(valid));
    level=NaN;observed=NaN;
    if ~isempty(predicted)
        predicted=predicted(1);[~,idx]=min(abs(angles-predicted));
        neighborhood=max(1,idx-20):min(numel(angles),idx+20);
        [peak,kidx]=max(response.amplitude(neighborhood));observed=angles(neighborhood(kidx));level=20*log10(peak);
        xline(predicted,'--',sprintf('Predicted %.2f deg',predicted),'HandleVisibility','off');
    else
        predicted=NaN;
    end
    rows{j}=struct('pattern',string(labels{j}),'active_elements',numel(positions), ...
        'effective_pitch_m',pitch,'steering_deg',20,'predicted_grating_angle_deg',predicted, ...
        'observed_nearby_peak_deg',observed,'grating_level_db_drive_reference',level);
end
ylim([-60 2]);xlim([-85 85]);grid on;legend('Location','best');
xlabel('Angle from +z in x-z plane (deg)');ylabel('Amplitude / summed active surface drive (dB)');
title({'SYNTHETIC far-field diagnostic: shared vs periodic 50% thinning', ...
    'Each curve has its own drive reference; absolute output loss is assessed in the 3-D comparison.'});
exportgraphics(fig,fullfile(output_dir,'grating_lobes.png'),'Resolution',160);close(fig);
summary=struct2table([rows{:}]);writetable(summary,fullfile(output_dir,'grating_summary.csv'));
writetable(table(angles,curves(:,1),curves(:,2),'VariableNames',{'angle_deg','shared_amplitude','checkerboard_amplitude'}), ...
    fullfile(output_dir,'angular_profiles.csv'));
save(fullfile(output_dir,'grating_config.mat'),'cfg','summary');disp(summary);
end
