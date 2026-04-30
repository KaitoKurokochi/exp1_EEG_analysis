% fig_freq_topo.m  [supplemental]
% Per-band x condition topo figure.
% Layout: Row 1 = Exp power, Row 2 = Nov power, Row 3 = Exp-Nov diff
% Columns: 0, 50, ..., 500 ms
% Requires stat_freq_cbpt.m to have been run first.
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

            [~, t_idx] = min(abs(s.stat.time - t));
            mask_t = s.stat.mask(:, t_idx);

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
            'String', sprintf('%s band - %s', bands{bi,2}, conditions{ci}), ...
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

        out_path = fullfile(res_dir, [conditions{ci}, '_', bands{bi,2}, '.svg']);
        print(fig, '-dsvg', out_path);
        close(fig);
        fprintf('Saved: %s\n', out_path);
    end
end

disp('Done.');
