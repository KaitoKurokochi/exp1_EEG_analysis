% fig_freq_diff_topo.m  [supplemental]
% Per-band diff topo figure (Go / No-Go / Go-NoGo).
% Layout: Row 1 = Go: Exp-Nov, Row 2 = NoGo: Exp-Nov, Row 3 = Go-NoGo diff
% Columns: 0, 50, ..., 500 ms
% Requires stat_freq_cbpt.m to have been run first.
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

    s_go   = load(fullfile(stat_data_dir, ['go_',   band_name, '.mat']));
    s_nogo = load(fullfile(stat_data_dir, ['nogo_', band_name, '.mat']));

    topo_imgs = cell(3, n_t);
    for ti = 1:n_t
        t = times(ti);

        [d_go, d_nogo, d_dd] = compute_diffs( ...
            freq_exp_go, freq_nov_go, freq_exp_nogo, freq_nov_nogo, ...
            bands{bi, 1}, t);

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

    out_path = fullfile(res_dir, sprintf('%s.svg', band_name));
    print(fig, '-dsvg', out_path);
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
