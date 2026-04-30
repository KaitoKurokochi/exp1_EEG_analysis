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
res_dir = fullfile(prj_dir, 'result', 'stat_erp_cond_cluster');
alpha = 0.05;

if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

for ci = 1:length(conditions)
    load(fullfile(data_erp_dir, ['exp_', conditions{ci}, '.mat']));
    data_exp_all = data; clear data;
    load(fullfile(data_erp_dir, ['nov_', conditions{ci}, '.mat']));
    data_nov_all = data; clear data;
    load(fullfile(data_stat_dir, [conditions{ci}, '.mat']));

    % pos clusters
    for cli = 1:length(stat.posclusters)
        if stat.posclusters(cli).prob >= alpha
            break
        end
    
        % extract cluster from labelmat
        cluster_mask = (stat.posclusterslabelmat == cli);
    
        % find channels
        chan_idx = find(any(cluster_mask, 2));
        chan_names = stat.label(chan_idx);
    
        % find time
        time_idx = find(any(cluster_mask, 1));
        time_range = stat.time(time_idx);

        % skip clusters outside 50–100ms duration
        cluster_dur = time_range(end) - time_range(1);
        if isempty(time_range) || cluster_dur < 0.05
            continue
        end

        % extract (time x chan)
        cfg = [];
        cfg.channel            = chan_names;
        cfg.latency            = [0.0 0.5];
        data_exp = ft_timelockanalysis(cfg, data_exp_all);
        data_nov = ft_timelockanalysis(cfg, data_nov_all);

        % data
        data = [];
        data.erp_exp = data_exp;
        data.erp_nov = data_nov;
        data.mask = cluster_mask(chan_idx, :);

        % save data
        save(fullfile(res_dir, [conditions{ci}, '_pos', num2str(cli), '.mat']), 'data', '-v7.3');
    end

    % neg clusters
    for cli = 1:length(stat.negclusters)
        if stat.negclusters(cli).prob >= alpha
            break
        end

        % extract cluster from labelmat
        cluster_mask = (stat.negclusterslabelmat == cli);

        % find channels
        chan_idx = find(any(cluster_mask, 2));
        chan_names = stat.label(chan_idx);

        % find time
        time_idx = find(any(cluster_mask, 1));
        time_range = stat.time(time_idx);

        % skip clusters outside 50–100ms duration
        cluster_dur = time_range(end) - time_range(1);
        if isempty(time_range) || cluster_dur < 0.05
            continue
        end

        % extract (time x chan)
        cfg = [];
        cfg.channel            = chan_names;
        cfg.latency            = [0.0 0.5];
        data_exp = ft_timelockanalysis(cfg, data_exp_all);
        data_nov = ft_timelockanalysis(cfg, data_nov_all);

        % data
        data = [];
        data.erp_exp = data_exp;
        data.erp_nov = data_nov;
        data.mask = cluster_mask(chan_idx, :);

        % save data
        save(fullfile(res_dir, [conditions{ci}, '_neg', num2str(cli), '.mat']), 'data', '-v7.3');
    end
end

%% figure - ERP per cluster (ERP waveform + topomap, SVG)
% One SVG per significant cluster: left = ERP averaged over cluster channels,
% right = topomap with cluster channels highlighted.
clear;
config;

data_cluster_dir = fullfile(prj_dir, 'result', 'stat_erp_cond_cluster');
data_erp_dir     = fullfile(prj_dir, 'result', 'erp_group_cond');
data_stat_dir    = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
data_rt_dir      = fullfile(prj_dir, 'result', 'stat_rt');
res_dir          = fullfile(prj_dir, 'result', 'fig_stat_erp_cbpt');
alpha            = 0.05;

if ~exist(res_dir, 'dir'), mkdir(res_dir); end

col_exp = [0.00, 0.45, 0.74];   % blue
col_nov = [0.85, 0.33, 0.10];   % red
col_sig = [0.85, 0.85, 0.85];   % gray significance shading

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
            if clusters(cli).prob >= alpha, break; end

            fpath = fullfile(data_cluster_dir, [conditions{ci}, '_', pol, num2str(cli), '.mat']);
            if ~exist(fpath, 'file'), continue; end
            load(fpath);   % loads 'data': data.erp_exp.label, data.mask

            % select cluster channels, restrict to 0-500 ms
            chan_names = data.erp_exp.label;
            cfg_sel = []; cfg_sel.channel = chan_names; cfg_sel.latency = [0.0, 0.5];
            avg_exp_ch = ft_selectdata(cfg_sel, avg_exp_full);
            avg_nov_ch = ft_selectdata(cfg_sel, avg_nov_full);

            erp_e = mean(avg_exp_ch.avg, 1) * 1e6;   % V → µV, mean over cluster chans
            erp_n = mean(avg_nov_ch.avg, 1) * 1e6;
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

            % --- assemble combined figure ---
            fig = figure('Visible', 'off', 'Units', 'centimeters', ...
                'Position', [0, 0, 16, 7]);

            % ERP panel (left)
            ax_erp = axes('Position', [0.09, 0.15, 0.56, 0.76]); %#ok<LAXES>
            hold on;

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
            xlabel('Time (s)', 'FontSize', 9);
            ylabel('\muV',     'FontSize', 9);
            legend([h_e, h_n], {'Experienced', 'Novice'}, ...
                'Location', 'southwest', 'FontSize', 8, 'Box', 'off');
            set(ax_erp, 'FontSize', 9, 'TickDir', 'out', 'Box', 'off');

            % Topomap panel (right, embedded raster) — square in 16x7 cm figure
            ax_topo = axes('Position', [0.70, 0.18, 0.28, 0.64]); %#ok<LAXES>
            image(ax_topo, topo_img);
            axis(ax_topo, 'image');
            axis(ax_topo, 'off');

            fname = [conditions{ci}, '_', pol, num2str(cli), '.svg'];
            print(fig, '-dsvg', fullfile(res_dir, fname));
            close(fig);
            fprintf('Saved: %s\n', fname);
        end
    end
end