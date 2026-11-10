function audit=curing_field_source_audit(manifest,outdir)
%CURING_FIELD_SOURCE_AUDIT Area/spectrum diagnostics for finite rectangular sources.
% Pure pre-propagation diagnostics: no k-Wave time stepping. The audit compares
% the grid-rasterized element aperture with the continuous 0.11 mm rectangle and
% records the discrete spectrum error up to the spatial Nyquist frequency.
if nargin<2 || isempty(outdir)
    outdir=fileparts(manifest.rows(1).mat);
end
if ~isfolder(outdir), mkdir(outdir); end
variants=iceind.curing_field_variants();
grids=[65e-6 52e-6];
domain=[15.6 10.4 31.2]*1e-3;
rows=struct('variant',{},'num_active',{},'dx_m',{},'cells_per_width',{}, ...
    'cells_per_height',{},'area_error_max_m2',{},'centroid_offset_max_m',{}, ...
    'effective_width_rel_err_max',{},'effective_height_rel_err_max',{}, ...
    'spectrum_l2_rel_err',{},'spectrum_max_abs_err',{},'spectrum_75deg_rel_err',{}, ...
    'aperture_span_m',{},'f_number',{},'edge_to_target_angle_deg',{}, ...
    'source_proxy_total_pa2_s_m2',{});
for vi=1:numel(variants)
    v=variants(vi); idx=find(strcmp({manifest.rows.name},v.name));
    assert(numel(idx)==1,'iceind:CuringField','Driver manifest lacks %s.',v.name);
    driverMat=manifest.rows(idx).mat;
    s=load(driverMat);
    b=iceind.compile_kwave(s);
    q=b.tx(1);
    active=find(q.apod~=0);
    assert(isequal(active,sort(v.ranks)),'iceind:CuringField','Rank mismatch in audit.');
    positions=b.geometry.positions_m;
    width=b.geometry.width_m; height=b.geometry.height_m; area=width*height;
    activeX=sort(positions(active,1));
    span=max(activeX)-min(activeX)+width;
    [~,im]=min(abs(activeX-mean(activeX)));
    rep=active(im); % representative element nearest the aperture centre
    for gi=1:numel(grids)
        dx=grids(gi); n=round(domain/dx);
        kg=kWaveGrid(n(1),dx,n(2),dx,n(3),dx);
        [w,wx,wy]=iceind.curing_field_weights(kg.x_vec,kg.y_vec,dx, ...
            positions(active,:),width,height);
        aerr=max(abs(sum(double(w),1)*dx^2-area));
        % Aggregate discrete-moment errors over every active element.
        cx=zeros(1,numel(active)); efw=zeros(1,numel(active));
        cy=zeros(1,numel(active)); efh=zeros(1,numel(active));
        for j=1:numel(active)
            ax=wx(:,j); ax=ax/sum(ax); xv=kg.x_vec(:);
            cx(j)=sum(ax.*xv);
            m2x=sum(ax.*(xv-cx(j)).^2);
            efw(j)=sqrt(12*m2x)/width-1;
            ay=wy(:,j); ay=ay/sum(ay); yv=kg.y_vec(:);
            cy(j)=sum(ay.*yv);
            m2y=sum(ay.*(yv-cy(j)).^2);
            efh(j)=sqrt(12*m2y)/height-1;
        end
        repJ=find(active==rep);
        sx=iceind.curing_field_representation(kg.x_vec,wx(:,repJ),dx,width);
        sy=iceind.curing_field_representation(kg.y_vec,wy(:,repJ),dx,height);
        lambda=b.sound_speed_m_s/q.frequency_hz;
        f75=sind(75)/lambda;
        fr=double(wx(:,repJ)); fr=fr/sum(fr);
        disc75=abs(sum(fr.*exp(-2i*pi*f75*kg.x_vec(:))));
        cont75=abs(sinc_local(width*f75));
        rows(end+1)=struct('variant',v.name,'num_active',v.num_active,'dx_m',dx, ...
            'cells_per_width',width/dx,'cells_per_height',height/dx, ...
            'area_error_max_m2',aerr,'centroid_offset_max_m', ...
                max(max(abs(cx-positions(active,1)')),max(abs(cy))), ...
            'effective_width_rel_err_max',max(abs(efw)), ...
            'effective_height_rel_err_max',max(abs(efh)), ...
            'spectrum_l2_rel_err',max(sx.spectrum_l2_relative_error, ...
                sy.spectrum_l2_relative_error), ...
            'spectrum_max_abs_err',max(sx.spectrum_max_abs_error, ...
                sy.spectrum_max_abs_error), ...
            'spectrum_75deg_rel_err',abs(disc75-cont75)/cont75, ...
            'aperture_span_m',span,'f_number',20e-3/span, ...
            'edge_to_target_angle_deg',atan(max(abs(activeX))/20e-3)*180/pi, ...
            'source_proxy_total_pa2_s_m2',NaN); %#ok<AGROW>
        % Equal assumed 1 Pa signal per active element; proxy scales with count
        % and with dt (which changes between grids), never acoustic energy.
        dt=0.2*dx/b.sound_speed_m_s; % diagnostic sampling proxy only
        waveEnd=max(q.delay_s)+q.duration_s+2e-6;
        [wv,~]=iceind.kw_waveform(q,dt,waveEnd,1);
        rows(end).source_proxy_total_pa2_s_m2= ...
            area*dt*sum(double(wv(active,:)).^2,'all');
    end
end
audit=struct('schema_version',1, ...
    'scope','pre-propagation finite-rectangle area/spectrum audit; no solve', ...
    'generated_local',datestr(now,30), ...
    'definitions',struct( ...
        'area_error','max_j |sum_voxels(w_j)*dx^2 - width*height|, m^2', ...
        'effective_width','sqrt(12*second_central_moment); exact rectangle gives width', ...
        'spectrum_l2_rel_err',['|||discrete(f)|-|sinc(width*f)|||_2 / |||sinc(width*f)|||_2, ' ...
            'f in [0,1/(2dx)], representative central element, ky=0'], ...
        'spectrum_75deg_rel_err','relative aperture-spectrum error at f=sin(75deg)/lambda, 6 MHz', ...
        'source_proxy','element_area*dt*sum_t(s(t)^2), Pa^2 s m^2; not power or energy'));
audit.grids_m=grids;
audit.domain_m=domain;
audit.rows=rows;
iceind.curing_field_write_json(fullfile(outdir,'source_audit.json'),audit);
t=struct2table(rows); writetable(t,fullfile(outdir,'source_audit.csv'),'Encoding','UTF-8');
fprintf('Source audit rows: %d; wrote %s\n',numel(rows),outdir);
end
function y=sinc_local(x)
y=ones(size(x)); nz=x~=0; y(nz)=sin(pi*x(nz))./(pi*x(nz));
end
