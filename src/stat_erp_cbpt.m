% statistics: cluster-based permutation test of ERP for each condition 
% data is trial x time x amplitude ERP data
% compare between groups
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond'); % set data dir
res_dir = fullfile(prj_dir, 'result', 'stat_erp_cbpt'); % set res dir
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

% neighbours
load(fullfile(prj_dir, 'src', 'neighbours.mat'));

% statistics - erp cbpt
for ci = 1:length(conditions)
    % read data
    disp('--- loading ERP data ---');
    % exp ERP
    load(fullfile(data_dir, ['exp_', conditions{ci}, '.mat'])); % include data
    data_exp = data;
    clear data;
    % nov ERP
    load(fullfile(data_dir, ['nov_', conditions{ci}, '.mat'])); % include data
    data_nov = data;
    clear data;

    % statistics
    cfg = [];
    cfg.latency          = [0.0 0.5];
    cfg.method           = 'ft_statistics_montecarlo';
    cfg.statistic        = 'ft_statfun_indepsamplesT'; 
    cfg.correctm         = 'cluster';
    cfg.clusteralpha     = 0.001; 
    cfg.clustertail      = 0; % plus and minus
    cfg.clusterstatistic = 'maxsum'; % set sum
    cfg.clusterthreshold = 'nonparametric_common';
    cfg.minnbchan        = 3;
    cfg.tail             = 0; % two-sided test
    cfg.alpha            = 0.025; % for two-sided test
    cfg.numrandomization = 10000;
    cfg.neighbours       = neighbours;
    cfg.computeprob      = 'yes';
    % design
    n_trl_exp = size(data_exp.trial, 2);
    n_trl_nov = size(data_nov.trial, 2);
    cfg.design = [ones(1, n_trl_exp), 2*ones(1, n_trl_nov)];
    cfg.ivar   = 1;
    stat = ft_timelockstatistics(cfg, data_exp, data_nov);

    % save data
    save(fullfile(res_dir, [conditions{ci}, '.mat']), 'stat', '-v7.3');
end

%% extract each cluster
clear;
config;

data_erp_dir = fullfile(prj_dir, 'result', 'erp_group_cond');
data_stat_dir = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
res_qua_dir = fullfile(prj_dir, 'result', 'stat_erp_clusters', 'qualified');
res_dis_dir = fullfile(prj_dir, 'result', 'stat_erp_clusters', 'disqualified');
alpha = 0.05;
% RT cutoff: clusters starting after this time are excluded as motor-related activity.
% Set to Expert fastest individual mean RT (Exp08: 327.0 ms).
% Note: Expert group mean RT (350.6 ms) is an alternative under discussion.
RT_CUTOFF = 0.327; % seconds

if ~exist(res_qua_dir, 'dir')
    mkdir(res_qua_dir);
end
if ~exist(res_dis_dir, 'dir')
    mkdir(res_dis_dir);
end

for ci = 1:length(conditions)
    load(fullfile(data_erp_dir, ['exp_', conditions{ci}, '.mat']));
    data_exp_all = data; clear data;
    load(fullfile(data_erp_dir, ['nov_', conditions{ci}, '.mat']));
    data_nov_all = data; clear data;
    load(fullfile(data_stat_dir, [conditions{ci}, '.mat']));

    % pos clusters
    for cli = 1:length(stat.posclusters)
        if isnan(stat.posclusters(cli).prob) || stat.posclusters(cli).prob >= alpha
            continue
        end

        % extract cluster from labelmat
        cluster_mask = (stat.posclusterslabelmat == cli);

        % find channels
        chan_idx = find(any(cluster_mask, 2));
        chan_names = stat.label(chan_idx);

        % find time
        time_idx = find(any(cluster_mask, 1));
        time_range = stat.time(time_idx);

        % skip clusters with no time points (edge case: missing from labelmat)
        if isempty(time_range)
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = NaN;
            data.t_end        = NaN;
            data.cluster_mask = cluster_mask;
            save(fullfile(res_dis_dir, [conditions{ci}, '_pos_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end
        cluster_dur = time_range(end) - time_range(1);
        % skip clusters shorter than 50 ms
        if cluster_dur < 0.05
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = time_range(1);
            data.t_end        = time_range(end);
            data.cluster_mask = cluster_mask;
            save(fullfile(res_dis_dir, [conditions{ci}, '_pos_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end

        % skip clusters overlapping with button press
        if time_range(end) > RT_CUTOFF
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = time_range(1);
            data.t_end        = time_range(end);
            data.cluster_mask = cluster_mask;
            save(fullfile(res_dis_dir, [conditions{ci}, '_pos_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end

        % extract (time x chan)
        cfg = [];
        cfg.channel            = chan_names;
        cfg.latency            = [0.0 0.5];
        data_exp = ft_timelockanalysis(cfg, data_exp_all);
        data_nov = ft_timelockanalysis(cfg, data_nov_all);

        % skip clusters where ERP waveform polarity reverses (novice > expert within pos cluster)
        [~, cl_t1] = min(abs(data_exp.time - time_range(1)));
        [~, cl_t2] = min(abs(data_exp.time - time_range(end)));
        erp_diff = mean(data_exp.avg, 1) - mean(data_nov.avg, 1);
        if any(erp_diff(cl_t1:cl_t2) < 0)
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = time_range(1);
            data.t_end        = time_range(end);
            data.cluster_mask = cluster_mask;
            data.erp_exp      = data_exp;
            data.erp_nov      = data_nov;
            save(fullfile(res_dis_dir, [conditions{ci}, '_pos_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end

        % data
        data = [];
        data.erp_exp = data_exp;
        data.erp_nov = data_nov;
        data.mask = cluster_mask(chan_idx, :);

        % save data
        save(fullfile(res_qua_dir, [conditions{ci}, '_pos_', num2str(cli), '.mat']), 'data', '-v7.3');
    end

    % neg clusters
    for cli = 1:length(stat.negclusters)
        if isnan(stat.negclusters(cli).prob) || stat.negclusters(cli).prob >= alpha
            continue
        end

        % extract cluster from labelmat
        cluster_mask = (stat.negclusterslabelmat == cli);

        % find channels
        chan_idx = find(any(cluster_mask, 2));
        chan_names = stat.label(chan_idx);

        % find time
        time_idx = find(any(cluster_mask, 1));
        time_range = stat.time(time_idx);

        % skip clusters with no time points (edge case: missing from labelmat)
        if isempty(time_range)
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = NaN;
            data.t_end        = NaN;
            data.cluster_mask = cluster_mask;
            save(fullfile(res_dis_dir, [conditions{ci}, '_neg_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end
        cluster_dur = time_range(end) - time_range(1);
        % skip clusters shorter than 50 ms
        if cluster_dur < 0.05
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = time_range(1);
            data.t_end        = time_range(end);
            data.cluster_mask = cluster_mask;
            save(fullfile(res_dis_dir, [conditions{ci}, '_neg_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end

        % skip clusters overlapping with button press
        if time_range(end) > RT_CUTOFF
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = time_range(1);
            data.t_end        = time_range(end);
            data.cluster_mask = cluster_mask;
            save(fullfile(res_dis_dir, [conditions{ci}, '_neg_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end

        % extract (time x chan)
        cfg = [];
        cfg.channel            = chan_names;
        cfg.latency            = [0.0 0.5];
        data_exp = ft_timelockanalysis(cfg, data_exp_all);
        data_nov = ft_timelockanalysis(cfg, data_nov_all);

        % skip clusters where ERP waveform polarity reverses (expert > novice within neg cluster)
        [~, cl_t1] = min(abs(data_exp.time - time_range(1)));
        [~, cl_t2] = min(abs(data_exp.time - time_range(end)));
        erp_diff = mean(data_exp.avg, 1) - mean(data_nov.avg, 1);
        if any(erp_diff(cl_t1:cl_t2) > 0)
            data = [];
            data.chan_names   = chan_names;
            data.t_start      = time_range(1);
            data.t_end        = time_range(end);
            data.cluster_mask = cluster_mask;
            data.erp_exp      = data_exp;
            data.erp_nov      = data_nov;
            save(fullfile(res_dis_dir, [conditions{ci}, '_neg_', num2str(cli), '.mat']), 'data', '-v7.3');
            continue
        end

        % data
        data = [];
        data.erp_exp = data_exp;
        data.erp_nov = data_nov;
        data.mask = cluster_mask(chan_idx, :);

        % save data
        save(fullfile(res_qua_dir, [conditions{ci}, '_neg_', num2str(cli), '.mat']), 'data', '-v7.3');
    end
end


%% figure - ERP per cluster (ERP waveform + topomap, SVG)
% Go and NoGo conditions are saved as separate SVG files.
% Layout: vertical stack — one row per cluster, each row contains
%   left panel = ERP waveform, right panel = topomap.
% Figure sizes: Go = 16x21 cm (3 rows), NoGo = 16x14 cm (2 rows).
clear;
config;

data_cluster_dir = fullfile(prj_dir, 'result', 'stat_erp_clusters', 'qualified');
data_erp_dir     = fullfile(prj_dir, 'result', 'erp_group_cond');
data_stat_dir    = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
data_rt_dir      = fullfile(prj_dir, 'result', 'stat_rt');
res_fig_qua_dir  = fullfile(prj_dir, 'result', 'fig_stat_erp_cbpt', 'qualified');
alpha            = 0.05;

% Single-row panel geometry (normalized, within one row slot)
% Matches original single-figure layout: 16x7 cm
erp_pos_in_slot  = [0.09, 0.15, 0.56, 0.76];  % [left, bot, w, h] within slot
topo_pos_in_slot = [0.66, 0.18, 0.32, 0.70];
row_margin       = 0.03;   % normalized gap between rows
pad_bot          = 0.02;   % normalized bottom margin for xlabel clearance

if ~exist(res_fig_qua_dir, 'dir'), mkdir(res_fig_qua_dir); end

col_exp = [0.00, 0.45, 0.74];   % blue
col_nov = [0.85, 0.33, 0.10];   % red
col_sig = [0.85, 0.85, 0.85];   % gray significance shading

load(fullfile(data_rt_dir, 'stat.mat'));
mean_rt_exp = mean(stat.exp.m_rt);
mean_rt_nov = mean(stat.nov.m_rt);

% output file names per condition
fig_fname = struct('go', 'go.svg', 'nogo', 'nogo.svg');

for ci = 1:length(conditions)
    cond = conditions{ci};   % 'go' or 'nogo'

    % grand average over full time range (all channels)
    load(fullfile(data_erp_dir, ['exp_', cond, '.mat']));
    cfg_avg = []; cfg_avg.keeptrials = 'no';
    avg_exp_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_erp_dir, ['nov_', cond, '.mat']));
    avg_nov_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_stat_dir, [cond, '.mat']));

    % --- Pass 1: collect all qualified clusters in loop order ---
    cluster_list = struct([]);

    for pol_i = 1:2
        if pol_i == 1, pol = 'pos'; clusters = stat.posclusters;
        else,          pol = 'neg'; clusters = stat.negclusters;
        end

        for cli = 1:length(clusters)
            if clusters(cli).prob >= alpha, break; end

            fpath = fullfile(data_cluster_dir, [cond, '_', pol, '_', num2str(cli), '.mat']);
            if ~exist(fpath, 'file'), continue; end
            load(fpath);   % loads 'data': data.erp_exp.label, data.mask

            % select cluster channels, restrict to 0-500 ms
            chan_names = data.erp_exp.label;
            cfg_sel = []; cfg_sel.channel = chan_names; cfg_sel.latency = [0.0, 0.5];
            avg_exp_ch = ft_selectdata(cfg_sel, avg_exp_full);
            avg_nov_ch = ft_selectdata(cfg_sel, avg_nov_full);

            erp_e = mean(avg_exp_ch.avg, 1);   % already in µV (FieldTrip reads BrainVision in µV)
            erp_n = mean(avg_nov_ch.avg, 1);
            t_erp = avg_exp_ch.time;

            % significance shading: any cluster channel significant at each stat time
            sig_t  = any(data.mask, 1);
            t_stat = stat.time;

            y_all = [erp_e, erp_n];
            pad_y = 0.15 * range(y_all);
            y_lo  = min(y_all) - pad_y;
            y_hi  = max(y_all) + pad_y;

            % --- capture topomap as image ---
            tmp_stat            = stat;
            tmp_stat.stat       = zeros(size(stat.stat));
            fig_tmp = figure('Visible', 'off', 'Units', 'pixels', ...
                'Position', [0 0 220 220]);
            cfg_t = [];
            cfg_t.parameter          = 'stat';
            cfg_t.layout             = 'easycapM11.mat';
            cfg_t.style              = 'blank';
            cfg_t.comment            = 'no';
            cfg_t.colorbar           = 'no';
            cfg_t.markers            = 'on';
            cfg_t.markersize         = 3;
            cfg_t.highlight          = 'on';
            cfg_t.highlightchannel   = chan_names;
            cfg_t.highlightsymbol    = 'o';
            cfg_t.highlightcolor     = [0.8 0 0];
            cfg_t.highlightsize      = 8;
            cfg_t.highlightlinewidth = 1.5;
            ft_topoplotER(cfg_t, tmp_stat);
            topo_img = print(fig_tmp, '-RGBImage');
            topo_img = imresize(topo_img, [220 220]);
            close(fig_tmp);

            % store cluster data for Pass 2
            entry.pol       = pol;
            entry.cli       = cli;
            entry.erp_e     = erp_e;
            entry.erp_n     = erp_n;
            entry.t_erp     = t_erp;
            entry.sig_t     = sig_t;
            entry.t_stat    = t_stat;
            entry.y_lo      = y_lo;
            entry.y_hi      = y_hi;
            entry.topo_img  = topo_img;
            if isempty(cluster_list)
                cluster_list = entry;
            else
                cluster_list(end+1) = entry; %#ok<AGROW>
            end
        end
    end

    if isempty(cluster_list)
        fprintf('No qualified clusters for condition: %s\n', cond);
        continue;
    end

    % --- Pass 2: assemble stacked figure ---
    n_rows    = length(cluster_list);
    fig_h_cm  = 7 * n_rows;   % 7 cm per row
    slot_h    = (1 - pad_bot - (n_rows - 1) * row_margin) / n_rows;   % normalized slot height

    fig = figure('Visible', 'off', 'Units', 'centimeters', ...
        'Position', [0, 0, 16, fig_h_cm]);

    for ri = 1:n_rows
        entry = cluster_list(ri);

        % slot bottom in normalized figure coordinates (top row first)
        slot_bot = pad_bot + (n_rows - ri) * (slot_h + row_margin);

        % ERP panel position: map erp_pos_in_slot into this slot
        erp_bot = slot_bot + erp_pos_in_slot(2) * slot_h;
        erp_h   = erp_pos_in_slot(4) * slot_h;
        ax_erp  = axes('Position', [erp_pos_in_slot(1), erp_bot, erp_pos_in_slot(3), erp_h]); %#ok<LAXES>
        hold on;

        d    = diff([false, entry.sig_t(:)', false]);
        ons  = find(d ==  1);
        offs = find(d == -1) - 1;
        for rii = 1:length(ons)
            fill([entry.t_stat(ons(rii)) entry.t_stat(offs(rii)) entry.t_stat(offs(rii)) entry.t_stat(ons(rii))], ...
                [entry.y_lo entry.y_lo entry.y_hi entry.y_hi], col_sig, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        end

        xline(0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
        yline(0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

        h_e = plot(entry.t_erp, entry.erp_e, 'Color', col_exp, 'LineWidth', 1.5);
        h_n = plot(entry.t_erp, entry.erp_n, 'Color', col_nov, 'LineWidth', 1.5);

        if strcmp(cond, 'go')
            xline(mean_rt_exp, '--', 'Color', col_exp, 'LineWidth', 1.0, 'Alpha', 0.6);
            xline(mean_rt_nov, '--', 'Color', col_nov, 'LineWidth', 1.0, 'Alpha', 0.6);
        end

        xlim([entry.t_erp(1), entry.t_erp(end)]);
        ylim([entry.y_lo, entry.y_hi]);
        xlabel('Time (s)', 'FontSize', 18);
        ylabel('\muV',     'FontSize', 18);
        lgd = legend([h_e, h_n], {'Experienced', 'Novice'}, ...
            'Location', 'southwest', 'FontSize', 12, 'Box', 'off');
        lgd.Position(1) = lgd.Position(1) - 0.02;   % shift legend slightly left
        set(ax_erp, 'FontSize', 18, 'TickDir', 'out', 'Box', 'off');

        % Topomap panel position: map topo_pos_in_slot into this slot
        topo_bot = slot_bot + topo_pos_in_slot(2) * slot_h;
        topo_h   = topo_pos_in_slot(4) * slot_h;
        ax_topo  = axes('Position', [topo_pos_in_slot(1), topo_bot, topo_pos_in_slot(3), topo_h]); %#ok<LAXES>
        image(ax_topo, entry.topo_img);
        axis(ax_topo, 'image');
        axis(ax_topo, 'off');
    end

    fname = fig_fname.(cond);
    print(fig, '-dsvg', fullfile(res_fig_qua_dir, fname));
    close(fig);
    fprintf('Saved: %s  (%d rows)\n', fname, n_rows);
end

%% save individual ERP and topomap PDFs (vector, Illustrator-ready)
% Saves each qualified cluster as two separate PDFs:
%   <cond>_<pol>_<cli>_erp.pdf  — ERP waveform panel (10 x 7 cm, vector)
%   <cond>_<pol>_<cli>_topo.pdf — scalp topomap    (4.5 x 4.5 cm, vector)
% Output directory: result/fig_stat_erp_cbpt/individual/
% Use arrange_erp.jsx to assemble these into the final Illustrator figure.
clear;
config;

data_cluster_dir = fullfile(prj_dir, 'result', 'stat_erp_clusters', 'qualified');
data_erp_dir     = fullfile(prj_dir, 'result', 'erp_group_cond');
data_stat_dir    = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
data_rt_dir      = fullfile(prj_dir, 'result', 'stat_rt');
ind_dir          = fullfile(prj_dir, 'result', 'fig_stat_erp_cbpt', 'individual');
if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end

alpha      = 0.05;
erp_w_cm   = 10.0;  % ERP panel figure width  (cm)
erp_h_cm   =  7.0;  % ERP panel figure height (cm)
topo_cm    =  4.5;  % topomap figure size     (cm, square)

col_exp = [0.00, 0.45, 0.74];
col_nov = [0.85, 0.33, 0.10];
col_sig = [0.85, 0.85, 0.85];

load(fullfile(data_rt_dir, 'stat.mat'));
mean_rt_exp = mean(stat.exp.m_rt);
mean_rt_nov = mean(stat.nov.m_rt);

disp('--- saving individual ERP + topomap PDFs ---');
for ci = 1:length(conditions)
    cond = conditions{ci};

    load(fullfile(data_erp_dir, ['exp_', cond, '.mat']));
    cfg_avg = []; cfg_avg.keeptrials = 'no';
    avg_exp_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_erp_dir, ['nov_', cond, '.mat']));
    avg_nov_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_stat_dir, [cond, '.mat']));

    for pol_i = 1:2
        if pol_i == 1, pol = 'pos'; clusters = stat.posclusters;
        else,          pol = 'neg'; clusters = stat.negclusters;
        end

        for cli = 1:length(clusters)
            if clusters(cli).prob >= alpha, break; end

            fpath = fullfile(data_cluster_dir, [cond, '_', pol, '_', num2str(cli), '.mat']);
            if ~exist(fpath, 'file'), continue; end
            load(fpath);

            tag        = sprintf('%s_%s_%d', cond, pol, cli);
            chan_names = data.erp_exp.label;

            cfg_sel = []; cfg_sel.channel = chan_names; cfg_sel.latency = [0.0, 0.5];
            avg_exp_ch = ft_selectdata(cfg_sel, avg_exp_full);
            avg_nov_ch = ft_selectdata(cfg_sel, avg_nov_full);

            erp_e  = mean(avg_exp_ch.avg, 1);
            erp_n  = mean(avg_nov_ch.avg, 1);
            t_erp  = avg_exp_ch.time;
            sig_t  = any(data.mask, 1);
            t_stat = stat.time;

            y_all = [erp_e, erp_n];
            pad_y = 0.15 * range(y_all);
            y_lo  = min(y_all) - pad_y;
            y_hi  = max(y_all) + pad_y;

            % ---- ERP waveform panel (vector PDF, 10 x 7 cm) ----------------
            fig_erp = figure('Visible', 'off', 'Units', 'centimeters', ...
                'Position', [0, 0, erp_w_cm, erp_h_cm]);
            ax_erp = axes(fig_erp); %#ok<LAXES>
            hold on;

            d    = diff([false, sig_t(:)', false]);
            ons  = find(d ==  1);
            offs = find(d == -1) - 1;
            for rii = 1:length(ons)
                fill([t_stat(ons(rii)) t_stat(offs(rii)) t_stat(offs(rii)) t_stat(ons(rii))], ...
                    [y_lo y_lo y_hi y_hi], col_sig, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
            end

            xline(0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
            yline(0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

            h_e = plot(t_erp, erp_e, 'Color', col_exp, 'LineWidth', 1.5);
            h_n = plot(t_erp, erp_n, 'Color', col_nov, 'LineWidth', 1.5);

            if strcmp(cond, 'go')
                xline(mean_rt_exp, '--', 'Color', col_exp, 'LineWidth', 1.0, 'Alpha', 0.6);
                xline(mean_rt_nov, '--', 'Color', col_nov, 'LineWidth', 1.0, 'Alpha', 0.6);
            end

            xlim([t_erp(1), t_erp(end)]);
            ylim([y_lo, y_hi]);
            xlabel('Time (s)', 'FontSize', 15);
            ylabel('\muV',     'FontSize', 15);
            legend([h_e, h_n], {'Experienced', 'Novice'}, ...
                'Location', 'southwest', 'FontSize', 11, 'Box', 'off');
            set(ax_erp, 'FontSize', 15, 'TickDir', 'out', 'Box', 'off');

            % Dynamic fit: TightInset reads the actual margins needed for
            % tick labels and axis labels, then repositions the axes so
            % nothing is clipped regardless of the waveform amplitude range.
            drawnow;
            ti = ax_erp.TightInset;   % [left, bottom, right, top] normalized
            ax_erp.Position = [ti(1), ti(2), ...
                                1 - ti(1) - ti(3), 1 - ti(2) - ti(4)];

            fname_erp = fullfile(ind_dir, [tag, '_erp.pdf']);
            exportgraphics(fig_erp, fname_erp, 'ContentType', 'vector');
            close(fig_erp);

            % ---- Topomap panel (vector PDF, 4.5 x 4.5 cm) ------------------
            tmp_stat       = stat;
            tmp_stat.stat  = zeros(size(stat.stat));
            fig_topo = figure('Visible', 'off', 'Units', 'centimeters', ...
                'Position', [0, 0, topo_cm, topo_cm]);
            cfg_t = [];
            cfg_t.parameter          = 'stat';
            cfg_t.layout             = 'easycapM11.mat';
            cfg_t.style              = 'blank';
            cfg_t.comment            = 'no';
            cfg_t.colorbar           = 'no';
            cfg_t.markers            = 'on';
            cfg_t.markersize         = 3;
            cfg_t.highlight          = 'on';
            cfg_t.highlightchannel   = chan_names;
            cfg_t.highlightsymbol    = 'o';
            cfg_t.highlightcolor     = [0.8 0 0];
            cfg_t.highlightsize      = 8;
            cfg_t.highlightlinewidth = 1.5;
            ft_topoplotER(cfg_t, tmp_stat);

            fname_topo = fullfile(ind_dir, [tag, '_topo.pdf']);
            exportgraphics(fig_topo, fname_topo, 'ContentType', 'vector');
            close(fig_topo);

            fprintf('  saved: %s\n', tag);
        end
    end
end
fprintf('Saved individual PDFs to:\n  %s\n', ind_dir);

%% figure - skipped clusters (ERP waveform + topomap, PNG)
% Visualise clusters that were excluded by the skip criteria.
% One PNG per skipped cluster; title includes skip reason.
clear;
config;

data_skip_dir    = fullfile(prj_dir, 'result', 'stat_erp_clusters', 'disqualified');
data_erp_dir     = fullfile(prj_dir, 'result', 'erp_group_cond');
data_stat_dir    = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
data_rt_dir      = fullfile(prj_dir, 'result', 'stat_rt');
res_fig_dis_dir  = fullfile(prj_dir, 'result', 'fig_stat_erp_cbpt', 'disqualified');
alpha            = 0.05;

if ~exist(res_fig_dis_dir, 'dir'), mkdir(res_fig_dis_dir); end

col_exp  = [0.00, 0.45, 0.74];   % blue
col_nov  = [0.85, 0.33, 0.10];   % red
col_sig  = [0.85, 0.85, 0.85];   % gray significance shading
col_skip = [0.95, 0.90, 0.70];   % light yellow — skipped cluster shading

load(fullfile(data_rt_dir, 'stat.mat'));
mean_rt_exp = mean(stat.exp.m_rt);
mean_rt_nov = mean(stat.nov.m_rt);

for ci = 1:length(conditions)
    % grand average over full time range (all channels)
    load(fullfile(data_erp_dir, ['exp_', conditions{ci}, '.mat']));
    cfg_avg = []; cfg_avg.keeptrials = 'no';
    avg_exp_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_erp_dir, ['nov_', conditions{ci}, '.mat']));
    avg_nov_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_stat_dir, [conditions{ci}, '.mat']));

    for pol_i = 1:2
        if pol_i == 1, pol = 'pos'; clusters = stat.posclusters;
        else,          pol = 'neg'; clusters = stat.negclusters;
        end

        for cli = 1:length(clusters)
            % only process clusters that were significant but then skipped
            if isnan(clusters(cli).prob) || clusters(cli).prob >= alpha, continue; end

            fpath_skip = fullfile(data_skip_dir, [conditions{ci}, '_', pol, '_', num2str(cli), '.mat']);
            if ~exist(fpath_skip, 'file'), continue; end
            load(fpath_skip);   % loads 'data'

            % ---- determine channel names and time range ----
            chan_names = data.chan_names;
            t_start    = data.t_start;
            t_end      = data.t_end;

            % ERP waveforms: use stored erp if available (polarity_reversal case),
            % otherwise compute from grand average
            if isfield(data, 'erp_exp') && isfield(data, 'erp_nov')
                avg_exp_ch = data.erp_exp;
                avg_nov_ch = data.erp_nov;
            elseif ~isempty(chan_names)
                cfg_sel = []; cfg_sel.channel = chan_names; cfg_sel.latency = [0.0, 0.5];
                avg_exp_ch = ft_selectdata(cfg_sel, avg_exp_full);
                avg_nov_ch = ft_selectdata(cfg_sel, avg_nov_full);
            else
                % no channel info (empty_time_range) — use all channels
                cfg_sel = []; cfg_sel.latency = [0.0, 0.5];
                avg_exp_ch = ft_selectdata(cfg_sel, avg_exp_full);
                avg_nov_ch = ft_selectdata(cfg_sel, avg_nov_full);
            end

            erp_e = mean(avg_exp_ch.avg, 1);   % already in µV
            erp_n = mean(avg_nov_ch.avg, 1);
            t_erp = avg_exp_ch.time;

            % significance shading from stat (all channels in cluster)
            cluster_mask = data.cluster_mask;
            sig_t  = any(cluster_mask, 1);
            t_stat = stat.time;

            y_all = [erp_e, erp_n];
            pad_y = 0.15 * range(y_all);
            if pad_y == 0, pad_y = 0.5; end
            y_lo  = min(y_all) - pad_y;
            y_hi  = max(y_all) + pad_y;

            % --- topomap ---
            tmp_stat      = stat;
            tmp_stat.stat = zeros(size(stat.stat));
            fig_tmp = figure('Visible', 'off', 'Units', 'pixels', ...
                'Position', [0 0 220 220]);
            cfg_t = [];
            cfg_t.parameter          = 'stat';
            cfg_t.layout             = 'easycapM11.mat';
            cfg_t.style              = 'blank';
            cfg_t.comment            = 'no';
            cfg_t.colorbar           = 'no';
            cfg_t.markers            = 'on';
            cfg_t.markersize         = 3;
            if ~isempty(chan_names)
                cfg_t.highlight          = 'on';
                cfg_t.highlightchannel   = chan_names;
                cfg_t.highlightsymbol    = 'o';
                cfg_t.highlightcolor     = [0.8 0 0];
                cfg_t.highlightsize      = 8;
                cfg_t.highlightlinewidth = 1.5;
            else
                cfg_t.highlight = 'off';
            end
            ft_topoplotER(cfg_t, tmp_stat);
            topo_img = print(fig_tmp, '-RGBImage');
            topo_img = imresize(topo_img, [220 220]);
            close(fig_tmp);

            % --- combined figure ---
            fig = figure('Visible', 'off', 'Units', 'centimeters', ...
                'Position', [0, 0, 16, 7]);

            % ERP panel (left)
            ax_erp = axes('Position', [0.09, 0.18, 0.56, 0.68]); %#ok<LAXES>
            hold on;

            % gray shading: cluster time span (may be empty for empty_time_range)
            if ~isnan(t_start) && ~isnan(t_end)
                fill([t_start t_end t_end t_start], [y_lo y_lo y_hi y_hi], ...
                    col_skip, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
            end

            % significance shading (cluster pixels from stat labelmat)
            d = diff([false, sig_t(:)', false]);
            ons  = find(d ==  1);
            offs = find(d == -1) - 1;
            for ri = 1:length(ons)
                fill([t_stat(ons(ri)) t_stat(offs(ri)) t_stat(offs(ri)) t_stat(ons(ri))], ...
                    [y_lo y_lo y_hi y_hi], col_sig, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
            end

            xline(0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
            yline(0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

            h_e = plot(t_erp, erp_e, 'Color', col_exp, 'LineWidth', 1.5);
            h_n = plot(t_erp, erp_n, 'Color', col_nov, 'LineWidth', 1.5);

            if strcmp(conditions{ci}, 'go')
                xline(mean_rt_exp, '--', 'Color', col_exp, 'LineWidth', 1.0, 'Alpha', 0.6);
                xline(mean_rt_nov, '--', 'Color', col_nov, 'LineWidth', 1.0, 'Alpha', 0.6);
            end

            xlim([t_erp(1), t_erp(end)]);
            ylim([y_lo, y_hi]);
            xlabel('Time (s)', 'FontSize', 18);
            ylabel('\muV',     'FontSize', 18);

            % build title
            title_str = sprintf('[SKIPPED] %s %s%d  p=%.4f', ...
                conditions{ci}, pol, cli, clusters(cli).prob);
            title(ax_erp, title_str, 'FontSize', 8, 'Interpreter', 'none');

            legend([h_e, h_n], {'Experienced', 'Novice'}, ...
                'Location', 'southwest', 'FontSize', 11.5, 'Box', 'off');
            set(ax_erp, 'FontSize', 18, 'TickDir', 'out', 'Box', 'off');

            % Topomap panel (right)
            ax_topo = axes('Position', [0.70, 0.18, 0.28, 0.64]); %#ok<LAXES>
            image(ax_topo, topo_img);
            axis(ax_topo, 'image');
            axis(ax_topo, 'off');

            fname = [conditions{ci}, '_', pol, '_', num2str(cli), '.png'];
            print(fig, '-dpng', '-r150', fullfile(res_fig_dis_dir, fname));
            close(fig);
            fprintf('Saved (skipped): %s\n', fname);
        end
    end
end