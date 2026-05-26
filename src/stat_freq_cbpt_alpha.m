% stat_freq_cbpt_alpha.m
% Spatio-temporal CBPT for alpha band only (7-13 Hz).
% Saves stat results and an SVG topo overview (1 row x 11 time points).

%% statistics
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(prj_dir, 'src', 'neighbours.mat'));

band_freq  = [7 13];
band_name  = 'alpha';

for ci = 1:length(conditions)
    disp(['--- loading freq data: ', conditions{ci}, ' ---']);
    load(fullfile(data_dir, ['exp_', conditions{ci}, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(data_dir, ['nov_', conditions{ci}, '.mat'])); freq_nov = freq; clear freq;

    cfg                  = [];
    cfg.channel          = {'all', '-EOG'};
    cfg.parameter        = 'powspctrm';
    cfg.frequency        = band_freq;
    cfg.avgoverfreq      = 'yes';
    cfg.latency          = [0.0, 0.5];
    cfg.method           = 'ft_statistics_montecarlo';
    cfg.statistic        = 'ft_statfun_indepsamplesT';
    cfg.correctm         = 'cluster';
    cfg.clusteralpha     = 0.001;
    cfg.clustertail      = 0;
    cfg.clusterstatistic = 'maxsum';
    cfg.clusterthreshold = 'nonparametric_common';
    cfg.minnbchan        = 3;
    cfg.tail             = 0;
    cfg.alpha            = 0.025;
    cfg.numrandomization = 10000;
    cfg.neighbours       = neighbours;
    cfg.computeprob      = 'yes';

    n_trl_exp  = size(freq_exp.powspctrm, 1);
    n_trl_nov  = size(freq_nov.powspctrm, 1);
    cfg.design = [ones(1, n_trl_exp), 2*ones(1, n_trl_nov)];
    cfg.ivar   = 1;

    stat = ft_freqstatistics(cfg, freq_exp, freq_nov);

    fname = fullfile(res_dir, [conditions{ci}, '_', band_name, '.mat']);
    save(fname, 'stat', '-v7.3');
    fprintf('saved: %s\n', fname);
end

%% figure - 1 row x 11 time points SVG per condition
clear;
config;

stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir       = fullfile(prj_dir, 'result', 'fig_freq_overview_topo');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

band_freq = [7 13];
band_name = 'alpha';

times   = 0:0.05:0.5;
n_times = length(times);

% layout constants (cm)
topo_sz    = 200;   % off-screen topo resolution (px)
label_w_cm = 2.0;   % row-label column width
topo_cm    = 2.2;   % width = height per topo cell
header_h_cm = 0.8;  % column-header height
pad_b_cm   = 0.25;  % bottom margin
gap_cb_cm  = 0.2;   % gap between topos and colorbar
cb_w_cm    = 0.6;   % colorbar column width
pad_r_cm   = 1.0;   % right margin

fig_w_cm = label_w_cm + n_times*topo_cm + gap_cb_cm + cb_w_cm + pad_r_cm;
fig_h_cm = header_h_cm + topo_cm + pad_b_cm;

disp('--- creating alpha 1-row x 11-time overview figures ---');
for ci = 1:length(conditions)
    cond = conditions{ci};

    load(fullfile(freq_data_dir, ['exp_', cond, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(freq_data_dir, ['nov_', cond, '.mat'])); freq_nov = freq; clear freq;
    s = load(fullfile(stat_data_dir, [cond, '_', band_name, '.mat']));

    % compute color limit from Exp and Nov data at all time points
    mx_abs_diff = 0;
    for ti = 1:n_times
        t = times(ti);
        cfg_sel           = [];
        cfg_sel.frequency = band_freq;
        cfg_sel.latency   = [t - 0.001, t + 0.001];
        cfg_avg            = [];
        cfg_avg.keeptrials = 'no';
        avg_exp = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
        avg_nov = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
        cfg_math           = [];
        cfg_math.operation = 'x1 - x2';
        cfg_math.parameter = 'powspctrm';
        d = ft_math(cfg_math, avg_exp, avg_nov);
        mx_abs_diff = max(mx_abs_diff, max(abs(d.powspctrm(:))));
    end
    zlim_diff = [-mx_abs_diff, mx_abs_diff];

    % render individual topos
    topo_imgs = cell(1, n_times);
    for ti = 1:n_times
        t = times(ti);
        cfg_sel           = [];
        cfg_sel.frequency = band_freq;
        cfg_sel.latency   = [t - 0.001, t + 0.001];
        cfg_avg            = [];
        cfg_avg.keeptrials = 'no';
        avg_exp  = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
        avg_nov  = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
        cfg_math           = [];
        cfg_math.operation = 'x1 - x2';
        cfg_math.parameter = 'powspctrm';
        freq_diff = ft_math(cfg_math, avg_exp, avg_nov);

        [~, t_idx] = min(abs(s.stat.time - t));
        mask_t = s.stat.mask(:, t_idx);

        fig_tmp = figure('Visible', 'off', 'Units', 'pixels', ...
            'Position', [0 0 topo_sz topo_sz]);
        cfg_t          = [];
        cfg_t.colorbar = 'no';
        cfg_t.layout   = 'easycapM11.mat';
        cfg_t.colormap = 'jet';
        cfg_t.zlim     = zlim_diff;
        cfg_t.comment  = 'no';
        cfg_t.title    = ' ';
        if any(mask_t)
            cfg_t.highlight        = 'on';
            cfg_t.highlightchannel = find(mask_t);
            cfg_t.highlightsymbol  = '*';
            cfg_t.highlightcolor   = [0 0 0];
            cfg_t.highlightsize    = 8;
        else
            cfg_t.highlight = 'off';
        end
        ft_topoplotTFR(cfg_t, freq_diff);
        topo_imgs{ti} = imresize(print(fig_tmp, '-RGBImage'), [topo_sz, topo_sz]);
        close(fig_tmp);
    end
    fprintf('  [%s] topos rendered\n', cond);

    % assemble composite figure
    fig = figure('Visible', 'off', 'Units', 'centimeters', ...
        'Position', [0, 0, fig_w_cm, fig_h_cm]);

    for ti = 1:n_times
        l  = (label_w_cm + (ti-1)*topo_cm) / fig_w_cm;
        b  = pad_b_cm / fig_h_cm;
        ax = axes('Position', [l, b, topo_cm/fig_w_cm, topo_cm/fig_h_cm]); %#ok<LAXES>
        image(ax, topo_imgs{ti});
        axis(ax, 'image');
        axis(ax, 'off');
    end

    % time labels (column header)
    hdr_b = (pad_b_cm + topo_cm) / fig_h_cm;
    for ti = 1:n_times
        l = (label_w_cm + (ti-1)*topo_cm) / fig_w_cm;
        annotation(fig, 'textbox', [l, hdr_b, topo_cm/fig_w_cm, header_h_cm/fig_h_cm], ...
            'String', sprintf('%d ms', round(times(ti)*1000)), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 10);
    end

    % band label (row label, rotated)
    annotation(fig, 'textbox', [0, pad_b_cm/fig_h_cm, label_w_cm/fig_w_cm, topo_cm/fig_h_cm], ...
        'String', 'Alpha', ...
        'EdgeColor', 'none', 'Rotation', 90, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold');

    % single colorbar on the right
    cb_l   = (label_w_cm + n_times*topo_cm + gap_cb_cm) / fig_w_cm;
    cb_w_n = cb_w_cm / fig_w_cm;
    b_cb   = pad_b_cm / fig_h_cm;
    h_cb   = topo_cm / fig_h_cm;
    ax_cb  = axes('Position', [cb_l, b_cb, cb_w_n, h_cb], 'Visible', 'off'); %#ok<LAXES>
    colormap(ax_cb, jet(256));
    clim(ax_cb, zlim_diff);
    colorbar(ax_cb, 'Position', [cb_l, b_cb, cb_w_n, h_cb]);

    out_path = fullfile(res_dir, [cond, '_alpha_topo.svg']);
    print(fig, '-dsvg', out_path);
    close(fig);
    fprintf('Saved: %s\n', out_path);
end

disp('Done.');
