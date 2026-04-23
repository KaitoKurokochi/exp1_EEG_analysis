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
    cfg.clusteralpha     = 0.05; 
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
        if isempty(time_range) || cluster_dur < 0.05 || cluster_dur > 0.1
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
        if isempty(time_range) || cluster_dur < 0.05 || cluster_dur > 0.1
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

% figure each cluster
clear;
config;

data_erp_dir = fullfile(prj_dir, 'result', 'stat_erp_cond_cluster');
data_stat_dir = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
data_rt_dir  = fullfile(prj_dir, 'result', 'stat_rt');
res_dir = fullfile(prj_dir, 'result', 'fig_stat_erp_cond_cluster');
alpha = 0.05;

if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

% load RT data and compute group means
load(fullfile(data_rt_dir, 'exp.mat')); % loads 'exp'
load(fullfile(data_rt_dir, 'nov.mat')); % loads 'nov'
mean_rt_exp = mean(exp.m_rt);
mean_rt_nov = mean(nov.m_rt);

for ci = 1:length(conditions)
    % load stat
    load(fullfile(data_stat_dir, [conditions{ci}, '.mat']));

    % pos clusters
    for cli = 1:length(stat.posclusters)
        if stat.posclusters(cli).prob >= alpha
            break
        end

        fpath = fullfile(data_erp_dir, [conditions{ci}, '_pos', num2str(cli), '.mat']);
        if ~exist(fpath, 'file'), continue; end
        load(fpath);
        data.erp_exp.mask = data.mask;

        % fig - ERP
        fig = figure('Visible', 'off');

        cfg = [];
        cfg.maskparameter = 'mask';
        cfg.maskstyle     = 'box';
        cfg.maskfacealpha = 0.2;
        cfg.linewidth     = 1.5;
        cfg.linecolor     = 'br';
        cfg.interactive   = 'no';
        cfg.title         = ' ';

        ft_singleplotER(cfg, data.erp_exp, data.erp_nov);
        if strcmp(conditions{ci}, 'go')
            yl = ylim;
            line([mean_rt_exp mean_rt_exp], yl, ...
                'Color', 'b', 'LineStyle', '--', 'LineWidth', 1.5);
            line([mean_rt_nov mean_rt_nov], yl, ...
                'Color', 'r', 'LineStyle', '--', 'LineWidth', 1.5);
        end

        xlabel('Time (s)');
        ylabel('Amplitude (uV)');
        grid on;
        set(gca, 'FontSize', 16);

        save_name = fullfile(res_dir, [conditions{ci}, '_pos', num2str(cli), '_erp.jpg']);
        saveas(fig, save_name);
        close(fig);

        % fig - chan
        fig = figure('Visible', 'off');

        tmp_stat = stat;
        tmp_stat.stat = zeros(size(stat.stat));

        cfg = [];
        cfg.parameter = 'stat';
        cfg.layout    = 'easycapM11.mat';
        cfg.style     = 'blank';
        cfg.comment    = 'no';
        cfg.colorbar   = 'no';
        cfg.markers    = 'on';
        cfg.markersize = 3;
        cfg.highlight          = 'on';
        cfg.highlightchannel   = data.erp_exp.label;
        cfg.highlightsymbol    = 'o';
        cfg.highlightcolor     = [1 0 0];
        cfg.highlightsize      = 10;
        cfg.highlightlinewidth = 2;

        ft_topoplotER(cfg, tmp_stat);

        save_name = fullfile(res_dir, [conditions{ci}, '_pos', num2str(cli), '_chan.jpg']);
        saveas(fig, save_name);
        close(fig);
    end

    % neg clusters
    for cli = 1:length(stat.negclusters)
        if stat.negclusters(cli).prob >= alpha
            break
        end

        fpath = fullfile(data_erp_dir, [conditions{ci}, '_neg', num2str(cli), '.mat']);
        if ~exist(fpath, 'file'), continue; end
        load(fpath);
        data.erp_exp.mask = data.mask;

        % fig - ERP
        fig = figure('Visible', 'off');

        cfg = [];
        cfg.maskparameter = 'mask';
        cfg.maskstyle     = 'box';
        cfg.maskfacealpha = 0.2;
        cfg.linewidth     = 1.5;
        cfg.linecolor     = 'br';
        cfg.interactive   = 'no';
        cfg.title         = ' ';

        ft_singleplotER(cfg, data.erp_exp, data.erp_nov);
        if strcmp(conditions{ci}, 'go')
            yl = ylim;
            line([mean_rt_exp mean_rt_exp], yl, ...
                'Color', 'b', 'LineStyle', '--', 'LineWidth', 1.5);
            line([mean_rt_nov mean_rt_nov], yl, ...
                'Color', 'r', 'LineStyle', '--', 'LineWidth', 1.5);
        end

        xlabel('Time (s)');
        ylabel('Amplitude (uV)');
        grid on;
        set(gca, 'FontSize', 16);

        save_name = fullfile(res_dir, [conditions{ci}, '_neg', num2str(cli), '_erp.jpg']);
        saveas(fig, save_name);
        close(fig);

        % fig - chan
        fig = figure('Visible', 'off');

        tmp_stat = stat;
        tmp_stat.stat = zeros(size(stat.stat));

        cfg = [];
        cfg.parameter = 'stat';
        cfg.layout    = 'easycapM11.mat';
        cfg.style     = 'blank';
        cfg.comment    = 'no';
        cfg.colorbar   = 'no';
        cfg.markers    = 'on';
        cfg.markersize = 3;
        cfg.highlight          = 'on';
        cfg.highlightchannel   = data.erp_exp.label;
        cfg.highlightsymbol    = 'o';
        cfg.highlightcolor     = [1 0 0];
        cfg.highlightsize      = 10;
        cfg.highlightlinewidth = 2;

        ft_topoplotER(cfg, tmp_stat);

        save_name = fullfile(res_dir, [conditions{ci}, '_neg', num2str(cli), '_chan.jpg']);
        saveas(fig, save_name);
        close(fig);
    end
end