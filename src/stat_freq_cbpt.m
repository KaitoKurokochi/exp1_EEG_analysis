% stat_freq_cbpt.m
% Spatio-temporal cluster-based permutation test of frequency power
% per band (averaged over frequencies within band) x full time range.
% One stat per condition x band → stat covers all channels x all times.
% Parameters match stat_erp_cbpt.m.

%% statistics
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(prj_dir, 'src', 'neighbours.mat'));

bands = { ...
    [4  7],   'Theta'; ...
    [7  13],  'alpha'; ...
    [13 30],  'beta'; ...
    [30 45],  'Low_gamma'; ...
    [60 90],  'High_gamma'};
n_bands = size(bands, 1);

for ci = 1:length(conditions)
    disp(['--- loading freq data: ', conditions{ci}, ' ---']);
    load(fullfile(data_dir, ['exp_', conditions{ci}, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(data_dir, ['nov_', conditions{ci}, '.mat'])); freq_nov = freq; clear freq;

    for bi = 1:n_bands
        fprintf('  band: %s\n', bands{bi, 2});

        cfg                  = [];
        cfg.channel          = {'all', '-EOG'};
        cfg.parameter        = 'powspctrm';
        cfg.frequency        = bands{bi, 1};
        cfg.avgoverfreq      = 'yes';
        cfg.latency          = [0.0, 0.5];
        cfg.method           = 'ft_statistics_montecarlo';
        cfg.statistic        = 'ft_statfun_indepsamplesT';
        cfg.correctm         = 'cluster';
        cfg.clusteralpha     = 0.05;
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

        fname = fullfile(res_dir, [conditions{ci}, '_', bands{bi, 2}, '.mat']);
        save(fname, 'stat', '-v7.3');
        fprintf('  saved: %s\n', fname);
    end
end

%% compute color limits for figures
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'stat_freq_cbpt');

bands = { ...
    [4  7],   'Theta'; ...
    [7  13],  'alpha'; ...
    [13 30],  'beta'; ...
    [30 45],  'Low_gamma'; ...
    [60 90],  'High_gamma'};
n_bands = size(bands, 1);

times = 0:0.05:0.5;

mx_abs_grp  = zeros(1, n_bands); % Exp and Nov absolute max
mx_abs_diff = zeros(1, n_bands); % Exp-Nov diff absolute max

for ci = 1:length(conditions)
    disp('--- computing color limits ---');
    load(fullfile(data_dir, ['exp_', conditions{ci}, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(data_dir, ['nov_', conditions{ci}, '.mat'])); freq_nov = freq; clear freq;

    for bi = 1:n_bands
        for t = times
            cfg_sel           = [];
            cfg_sel.frequency = bands{bi, 1};
            cfg_sel.latency   = [t-0.001, t+0.001];
            cfg_avg            = [];
            cfg_avg.keeptrials = 'no';
            avg_exp = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
            avg_nov = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
            mx_abs_grp(bi)  = max(mx_abs_grp(bi),  max(abs(avg_exp.powspctrm(:))));
            mx_abs_grp(bi)  = max(mx_abs_grp(bi),  max(abs(avg_nov.powspctrm(:))));

            cfg_math           = [];
            cfg_math.operation = 'x1 - x2';
            cfg_math.parameter = 'powspctrm';
            d = ft_math(cfg_math, avg_exp, avg_nov);
            mx_abs_diff(bi) = max(mx_abs_diff(bi), max(abs(d.powspctrm(:))));
        end
    end
end

vals = [];
vals.bands       = bands;
vals.mx_abs_grp  = mx_abs_grp;
vals.mx_abs_diff = mx_abs_diff;
save(fullfile(res_dir, 'val.mat'), 'vals', '-v7.3');

%% figure - topo
% Layout per band x condition (one PNG each):
%   Row 1: Exp power
%   Row 2: Nov power
%   Row 3: Exp - Nov diff  (* = significant channels from CBPT mask)
%   Columns: 0, 50, 100, ..., 500 ms
clear;
config;

stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir       = fullfile(prj_dir, 'result', 'fig_stat_freq_cbpt_topo');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(stat_data_dir, 'val.mat'));

bands = { ...
    [4  7],   'Theta'; ...
    [7  13],  'alpha'; ...
    [13 30],  'beta'; ...
    [30 45],  'Low_gamma'; ...
    [60 90],  'High_gamma'};
n_bands = size(bands, 1);

times   = 0:0.05:0.5;
n_times = length(times);

% layout constants (pixels)
topo_sz  = 220;
label_w  = 80;
title_h  = 40;
header_h = 34;
cb_w     = 55;
pad      = 8;

fig_w_px = label_w + n_times * topo_sz + cb_w + pad;
fig_h_px = title_h + header_h + 3 * topo_sz + pad;

disp('--- creating figures ---');
for ci = 1:length(conditions)
    load(fullfile(freq_data_dir, ['exp_', conditions{ci}, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(freq_data_dir, ['nov_', conditions{ci}, '.mat'])); freq_nov = freq; clear freq;

    for bi = 1:n_bands
        zlim_grp  = [-vals.mx_abs_grp(bi),  vals.mx_abs_grp(bi)];
        zlim_diff = [-vals.mx_abs_diff(bi),  vals.mx_abs_diff(bi)];

        % load spatio-temporal stat (mask: n_chans x n_stat_times)
        s = load(fullfile(stat_data_dir, [conditions{ci}, '_', bands{bi,2}, '.mat']));

        % capture topomaps into images (off-screen)
        topo_imgs = cell(3, n_times);
        for ti = 1:n_times
            t = times(ti);

            cfg_sel           = [];
            cfg_sel.frequency = bands{bi, 1};
            cfg_sel.latency   = [t-0.001, t+0.001];
            cfg_avg            = [];
            cfg_avg.keeptrials = 'no';
            avg_exp  = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
            avg_nov  = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
            cfg_math           = [];
            cfg_math.operation = 'x1 - x2';
            cfg_math.parameter = 'powspctrm';
            freq_diff = ft_math(cfg_math, avg_exp, avg_nov);

            % stat.mask is [n_chans x n_times] (freq averaged by avgoverfreq)
            [~, t_idx] = min(abs(s.stat.time - t));
            mask_t = s.stat.mask(:, t_idx); % n_chans x 1

            row_data  = {avg_exp,      avg_nov,      freq_diff};
            row_zlims = {zlim_grp,     zlim_grp,     zlim_diff};
            row_masks = {logical([]),  logical([]),   mask_t};

            for r = 1:3
                fig_tmp = figure('Visible', 'off', 'Units', 'pixels', ...
                    'Position', [0 0 topo_sz topo_sz]);
                cfg_t          = [];
                cfg_t.colorbar = 'no';
                cfg_t.layout   = 'easycapM11.mat';
                cfg_t.colormap = 'jet';
                cfg_t.zlim     = row_zlims{r};
                cfg_t.comment  = 'no';
                cfg_t.title    = ' ';
                if any(row_masks{r}(:))
                    cfg_t.highlight        = 'on';
                    cfg_t.highlightchannel = find(row_masks{r});
                    cfg_t.highlightsymbol  = '*';
                    cfg_t.highlightcolor   = [0 0 0];
                else
                    cfg_t.highlight = 'off';
                end
                ft_topoplotTFR(cfg_t, row_data{r});
                topo_imgs{r, ti} = print(fig_tmp, '-RGBImage');
                close(fig_tmp);
            end
        end

        % resize to exact topo_sz
        for r = 1:3
            for ti = 1:n_times
                topo_imgs{r, ti} = imresize(topo_imgs{r, ti}, [topo_sz, topo_sz]);
            end
        end

        % assemble composite figure
        fig = figure('Visible', 'off', 'Units', 'pixels', ...
            'Position', [0, 0, fig_w_px, fig_h_px]);

        for r = 1:3
            for c = 1:n_times
                l = (label_w + (c-1)*topo_sz) / fig_w_px;
                b = (pad      + (3-r)*topo_sz) / fig_h_px;
                ax = axes('Position', [l, b, topo_sz/fig_w_px, topo_sz/fig_h_px]); %#ok<LAXES>
                image(ax, topo_imgs{r, c});
                axis(ax, 'off');
            end
        end

        % time labels
        for c = 1:n_times
            l = (label_w + (c-1)*topo_sz) / fig_w_px;
            b = (pad + 3*topo_sz)          / fig_h_px;
            annotation(fig, 'textbox', [l, b, topo_sz/fig_w_px, header_h/fig_h_px], ...
                'String', sprintf('%d ms', round(times(c)*1000)), ...
                'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'FontSize', 9);
        end

        % row labels
        row_labels = {'Exp', 'Nov', 'Exp - Nov'};
        for r = 1:3
            b = (pad + (3-r)*topo_sz) / fig_h_px;
            annotation(fig, 'textbox', [0, b, label_w/fig_w_px, topo_sz/fig_h_px], ...
                'String', row_labels{r}, 'EdgeColor', 'none', 'Rotation', 90, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 11, 'FontWeight', 'bold');
        end

        % title
        annotation(fig, 'textbox', ...
            [label_w/fig_w_px, (pad+header_h+3*topo_sz)/fig_h_px, ...
             n_times*topo_sz/fig_w_px, title_h/fig_h_px], ...
            'String', sprintf('%s band – %s', bands{bi,2}, conditions{ci}), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 13, 'FontWeight', 'bold');

        % colorbars
        cb_l   = (label_w + n_times*topo_sz + 4) / fig_w_px;
        cb_w_n = (cb_w - 8) / fig_w_px;
        zlims_cb = {zlim_grp, zlim_grp, zlim_diff};
        for r = 1:3
            b_cb  = (pad + (3-r)*topo_sz) / fig_h_px;
            h_cb  = topo_sz / fig_h_px;
            ax_cb = axes('Position', [cb_l, b_cb, cb_w_n, h_cb], 'Visible', 'off'); %#ok<LAXES>
            colormap(ax_cb, jet(256));
            clim(ax_cb, zlims_cb{r});
            colorbar(ax_cb, 'Position', [cb_l, b_cb, cb_w_n, h_cb]);
        end

        out_path = fullfile(res_dir, [conditions{ci}, '_', bands{bi,2}, '.png']);
        exportgraphics(fig, out_path, 'Resolution', 150);
        close(fig);
        fprintf('Saved: %s\n', out_path);
    end
end

disp('Done.');

%% figure - diff topo (Go / No-Go / Go-NoGo per band)
% Layout per band (one PNG each):
%   Row 1 (Go):       Exp - Nov diff, * = significant channels
%   Row 2 (No-Go):    Exp - Nov diff, * = significant channels
%   Row 3 (Go-NoGo):  (Exp-Nov Go) - (Exp-Nov No-Go), no CBPT
%   Columns: 0, 50, 100, ..., 500 ms
clear;
config;

stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir       = fullfile(prj_dir, 'result', 'fig_supp_freq_diff_topo');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(stat_data_dir, 'val.mat'));

bands = { ...
    [4  7],   'Theta'; ...
    [7  13],  'alpha'; ...
    [13 30],  'beta'; ...
    [30 45],  'Low_gamma'; ...
    [60 90],  'High_gamma'};
n_bands = size(bands, 1);

times = 0:0.05:0.5;
n_t   = length(times);

disp('--- loading freq data ---');
load(fullfile(freq_data_dir, 'exp_go.mat'));   freq_exp_go   = freq; clear freq;
load(fullfile(freq_data_dir, 'nov_go.mat'));   freq_nov_go   = freq; clear freq;
load(fullfile(freq_data_dir, 'exp_nogo.mat')); freq_exp_nogo = freq; clear freq;
load(fullfile(freq_data_dir, 'nov_nogo.mat')); freq_nov_nogo = freq; clear freq;

% compute color limits for Go-NoGo row
disp('--- computing color limits ---');
mx_abs_dd = zeros(1, n_bands);
for bi = 1:n_bands
    for ti = 1:n_t
        [~, ~, d_dd] = compute_diffs( ...
            freq_exp_go, freq_nov_go, freq_exp_nogo, freq_nov_nogo, ...
            bands{bi, 1}, times(ti));
        mx_abs_dd(bi) = max(mx_abs_dd(bi), max(abs(d_dd.powspctrm(:))));
    end
end

% layout constants (pixels)
topo_sz  = 220;
label_w  = 80;
title_h  = 40;
header_h = 34;
cb_w     = 55;
pad      = 8;

fig_w_px = label_w + n_t * topo_sz + cb_w + pad;
fig_h_px = title_h + header_h + 3 * topo_sz + pad;

disp('--- creating figures ---');
for bi = 1:n_bands
    band_name = bands{bi, 2};
    zlim_cond = [-vals.mx_abs_diff(bi), vals.mx_abs_diff(bi)];
    zlim_dd   = [-mx_abs_dd(bi),        mx_abs_dd(bi)];

    % load spatio-temporal stats for go and nogo
    s_go   = load(fullfile(stat_data_dir, ['go_',   band_name, '.mat']));
    s_nogo = load(fullfile(stat_data_dir, ['nogo_', band_name, '.mat']));

    topo_imgs = cell(3, n_t);
    for ti = 1:n_t
        t    = times(ti);
        t_ms = round(t * 1000);

        [d_go, d_nogo, d_dd] = compute_diffs( ...
            freq_exp_go, freq_nov_go, freq_exp_nogo, freq_nov_nogo, ...
            bands{bi, 1}, t);

        % extract mask at nearest time point
        [~, t_idx_go]   = min(abs(s_go.stat.time   - t));
        [~, t_idx_nogo] = min(abs(s_nogo.stat.time - t));
        mask_go   = s_go.stat.mask(:,   t_idx_go);
        mask_nogo = s_nogo.stat.mask(:, t_idx_nogo);

        row_data  = {d_go,       d_nogo,      d_dd};
        row_zlims = {zlim_cond,  zlim_cond,   zlim_dd};
        row_masks = {mask_go,    mask_nogo,   logical([])};

        for r = 1:3
            fig_tmp = figure('Visible', 'off', 'Units', 'pixels', ...
                'Position', [0 0 topo_sz topo_sz]);
            cfg_t          = [];
            cfg_t.colorbar = 'no';
            cfg_t.layout   = 'easycapM11.mat';
            cfg_t.colormap = 'jet';
            cfg_t.zlim     = row_zlims{r};
            cfg_t.comment  = 'no';
            cfg_t.title    = ' ';
            if any(row_masks{r}(:))
                cfg_t.highlight        = 'on';
                cfg_t.highlightchannel = find(row_masks{r});
                cfg_t.highlightsymbol  = '*';
                cfg_t.highlightcolor   = [0 0 0];
            else
                cfg_t.highlight = 'off';
            end
            ft_topoplotTFR(cfg_t, row_data{r});
            topo_imgs{r, ti} = print(fig_tmp, '-RGBImage');
            close(fig_tmp);
        end
    end

    for r = 1:3
        for ti = 1:n_t
            topo_imgs{r, ti} = imresize(topo_imgs{r, ti}, [topo_sz, topo_sz]);
        end
    end

    fig = figure('Visible', 'off', 'Units', 'pixels', ...
        'Position', [0, 0, fig_w_px, fig_h_px]);

    for r = 1:3
        for c = 1:n_t
            l = (label_w + (c-1)*topo_sz) / fig_w_px;
            b = (pad      + (3-r)*topo_sz) / fig_h_px;
            ax = axes('Position', [l, b, topo_sz/fig_w_px, topo_sz/fig_h_px]); %#ok<LAXES>
            image(ax, topo_imgs{r, c});
            axis(ax, 'off');
        end
    end

    for c = 1:n_t
        l = (label_w + (c-1)*topo_sz) / fig_w_px;
        b = (pad + 3*topo_sz)          / fig_h_px;
        annotation(fig, 'textbox', [l, b, topo_sz/fig_w_px, header_h/fig_h_px], ...
            'String', sprintf('%d ms', round(times(c)*1000)), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 9);
    end

    row_labels = {'Go', 'No-Go', 'Go - No-Go'};
    for r = 1:3
        b = (pad + (3-r)*topo_sz) / fig_h_px;
        annotation(fig, 'textbox', [0, b, label_w/fig_w_px, topo_sz/fig_h_px], ...
            'String', row_labels{r}, 'EdgeColor', 'none', 'Rotation', 90, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 11, 'FontWeight', 'bold');
    end

    annotation(fig, 'textbox', ...
        [label_w/fig_w_px, (pad+header_h+3*topo_sz)/fig_h_px, ...
         n_t*topo_sz/fig_w_px, title_h/fig_h_px], ...
        'String', sprintf('%s band: Power Diff (Exp - Nov)', band_name), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', 13, 'FontWeight', 'bold');

    cb_l     = (label_w + n_t*topo_sz + 4) / fig_w_px;
    cb_w_n   = (cb_w - 8) / fig_w_px;
    zlims_cb = {zlim_cond, zlim_cond, zlim_dd};
    for r = 1:3
        b_cb  = (pad + (3-r)*topo_sz) / fig_h_px;
        h_cb  = topo_sz / fig_h_px;
        ax_cb = axes('Position', [cb_l, b_cb, cb_w_n, h_cb], 'Visible', 'off'); %#ok<LAXES>
        colormap(ax_cb, jet(256));
        clim(ax_cb, zlims_cb{r});
        colorbar(ax_cb, 'Position', [cb_l, b_cb, cb_w_n, h_cb]);
    end

    out_path = fullfile(res_dir, sprintf('%s.png', band_name));
    exportgraphics(fig, out_path, 'Resolution', 150);
    close(fig);
    fprintf('Saved: %s\n', out_path);
end

disp('Done.');

% -----------------------------------------------------------------------
% local functions
% -----------------------------------------------------------------------

function [d_go, d_nogo, d_dd] = compute_diffs( ...
        freq_exp_go, freq_nov_go, freq_exp_nogo, freq_nov_nogo, band, t)
    cfg_sel           = [];
    cfg_sel.frequency = band;
    cfg_sel.latency   = [t - 0.001, t + 0.001];

    cfg_avg            = [];
    cfg_avg.keeptrials = 'no';
    avg_exp_go   = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp_go));
    avg_nov_go   = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov_go));
    avg_exp_nogo = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp_nogo));
    avg_nov_nogo = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov_nogo));

    cfg_m           = [];
    cfg_m.operation = 'x1 - x2';
    cfg_m.parameter = 'powspctrm';
    d_go   = ft_math(cfg_m, avg_exp_go,   avg_nov_go);
    d_nogo = ft_math(cfg_m, avg_exp_nogo, avg_nov_nogo);
    d_dd   = ft_math(cfg_m, d_go,         d_nogo);
end
