% stat_freq_cbpt.m
% Spatio-temporal CBPT of EEG power for six frequency bands.
%
% Each band uses dedicated band-specific wavelet data (5 log-spaced frequency
% points per band, following Minami et al., 2024; wavelet width from
% Minami & Amano, 2017). Run erp_to_freq_bands.m first.
%
% Frequency bands (Minami et al., 2024):
%   delta      1– 4 Hz  → freq_group_cond_delta/
%   theta      4– 7 Hz  → freq_group_cond_theta/
%   alpha      7–13 Hz  → freq_group_cond_alpha/
%   beta      13–30 Hz  → freq_group_cond_beta/
%   low-gamma 30–45 Hz  → freq_group_cond_lowgamma/
%   high-gamma60–95 Hz  → freq_group_cond_highgamma/
%
% Sections:
%   1. statistics           — CBPT per condition × band
%   2. color limits         — zlim per band from band-specific data
%   3. composite figure     — 6 bands × 11 times SVG+PDF per condition
%   4. individual PDFs      — vector PDFs for Illustrator layout (arrange_supp_*.jsx)

% Bands: {[f_lo f_hi], stat_name, data_directory}
%   stat_name  : used in output filename, e.g. go_delta.mat
%   data_directory : subdirectory under result/ for band-specific wavelet data
BANDS_DEF = { ...
    [1  4],  'delta',     'freq_group_cond_delta'; ...
    [4  7],  'Theta',     'freq_group_cond_theta'; ...
    [7  13], 'alpha',     'freq_group_cond_alpha'; ...
    [13 30], 'beta',      'freq_group_cond_beta'; ...
    [30 45], 'Low_gamma', 'freq_group_cond_lowgamma'; ...
    [60 95], 'High_gamma','freq_group_cond_highgamma'};

%% statistics — one CBPT per condition × band
clear;
config;

BANDS_DEF = { ...
    [1  4],  'delta',     'freq_group_cond_delta'; ...
    [4  7],  'Theta',     'freq_group_cond_theta'; ...
    [7  13], 'alpha',     'freq_group_cond_alpha'; ...
    [13 30], 'beta',      'freq_group_cond_beta'; ...
    [30 45], 'Low_gamma', 'freq_group_cond_lowgamma'; ...
    [60 95], 'High_gamma','freq_group_cond_highgamma'};
n_bands = size(BANDS_DEF, 1);

res_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(prj_dir, 'src', 'neighbours.mat'));

for bi = 1:n_bands
    band_freq = BANDS_DEF{bi, 1};
    band_name = BANDS_DEF{bi, 2};
    band_dir  = fullfile(prj_dir, 'result', BANDS_DEF{bi, 3});

    fprintf('=== %s (%.0f–%.0f Hz) ===\n', band_name, band_freq(1), band_freq(2));

    for ci = 1:length(conditions)
        fprintf('  condition: %s\n', conditions{ci});
        load(fullfile(band_dir, ['exp_', conditions{ci}, '.mat'])); freq_exp = freq; clear freq;
        load(fullfile(band_dir, ['nov_', conditions{ci}, '.mat'])); freq_nov = freq; clear freq;

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
        fprintf('  saved: %s\n', fname);
    end
end

disp('Section 1 done.');

%% compute color limits for figures
clear;
config;

BANDS_DEF = { ...
    [1  4],  'delta',     'freq_group_cond_delta'; ...
    [4  7],  'Theta',     'freq_group_cond_theta'; ...
    [7  13], 'alpha',     'freq_group_cond_alpha'; ...
    [13 30], 'beta',      'freq_group_cond_beta'; ...
    [30 45], 'Low_gamma', 'freq_group_cond_lowgamma'; ...
    [60 95], 'High_gamma','freq_group_cond_highgamma'};
n_bands = size(BANDS_DEF, 1);

res_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
times   = 0:0.05:0.5;

mx_abs_grp  = zeros(1, n_bands);
mx_abs_diff = zeros(1, n_bands);

for bi = 1:n_bands
    band_freq = BANDS_DEF{bi, 1};
    band_name = BANDS_DEF{bi, 2};
    band_dir  = fullfile(prj_dir, 'result', BANDS_DEF{bi, 3});

    fprintf('--- zlim: %s ---\n', band_name);

    for ci = 1:length(conditions)
        load(fullfile(band_dir, ['exp_', conditions{ci}, '.mat'])); freq_exp = freq; clear freq;
        load(fullfile(band_dir, ['nov_', conditions{ci}, '.mat'])); freq_nov = freq; clear freq;

        for t = times
            cfg_sel           = [];
            cfg_sel.frequency = band_freq;
            cfg_sel.latency   = [t - 0.001, t + 0.001];
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
    fprintf('  zlim diff: [%.4f, %.4f]\n', -mx_abs_diff(bi), mx_abs_diff(bi));
end

vals = [];
vals.BANDS_DEF   = BANDS_DEF;
vals.mx_abs_grp  = mx_abs_grp;
vals.mx_abs_diff = mx_abs_diff;
save(fullfile(res_dir, 'val.mat'), 'vals', '-v7.3');
fprintf('Saved val.mat -> %s\n', res_dir);

disp('Section 2 done.');

%% individual topomap PDFs per condition (vector, for Illustrator layout)
% Saves per-condition × band × time group-difference topomaps and per-band
% colorbars as vector PDFs to:
%   result/fig_freq_overview_topo/{cond}_individual/
%
% File naming:
%   {band_name}_{ms}ms.pdf   e.g.  delta_000ms.pdf, Theta_050ms.pdf
%   colorbar_{band_name}.pdf e.g.  colorbar_delta.pdf
%
% Color limits are loaded from val.mat (section 2).
% The Illustrator scripts (arrange_supp_go.jsx / arrange_supp_nogo.jsx) read
% from these folders to assemble the final supplementary figures.

clear;
config;

BANDS_DEF = { ...
    [1  4],  'delta',     'freq_group_cond_delta'; ...
    [4  7],  'Theta',     'freq_group_cond_theta'; ...
    [7  13], 'alpha',     'freq_group_cond_alpha'; ...
    [13 30], 'beta',      'freq_group_cond_beta'; ...
    [30 45], 'Low_gamma', 'freq_group_cond_lowgamma'; ...
    [60 95], 'High_gamma','freq_group_cond_highgamma'};
n_bands = size(BANDS_DEF, 1);

stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
res_dir       = fullfile(prj_dir, 'result', 'fig_freq_overview_topo');

load(fullfile(stat_data_dir, 'val.mat'));

times   = 0:0.05:0.5;
n_times = length(times);
topo_sz = 400;

% colorbar layout constants (match stat_freq_cbpt_alpha.m section 3)
topo_cm_cb = 2.96;
cb_w_cm    = 0.40;
tick_cm    = 1.00;
pad_l_cm   = 0.20;
pad_r_cm   = 0.20;
pad_v_cm   = 0.30;
fig_cb_w   = pad_l_cm + cb_w_cm + tick_cm + pad_r_cm;
fig_cb_h   = topo_cm_cb + 2*pad_v_cm;
cb_x  = pad_l_cm   / fig_cb_w;
cb_wn = cb_w_cm    / fig_cb_w;
cb_y  = pad_v_cm   / fig_cb_h;
cb_hn = topo_cm_cb / fig_cb_h;

for ci = 1:length(conditions)
    cond    = conditions{ci};
    ind_dir = fullfile(res_dir, [cond, '_individual']);
    if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end

    for bi = 1:n_bands
        band_freq = BANDS_DEF{bi, 1};
        band_name = BANDS_DEF{bi, 2};
        band_dir  = fullfile(prj_dir, 'result', BANDS_DEF{bi, 3});
        zlim_diff = [-vals.mx_abs_diff(bi), vals.mx_abs_diff(bi)];

        load(fullfile(band_dir, ['exp_', cond, '.mat'])); freq_exp = freq; clear freq;
        load(fullfile(band_dir, ['nov_', cond, '.mat'])); freq_nov = freq; clear freq;
        s = load(fullfile(stat_data_dir, [cond, '_', band_name, '.mat']));

        % --- individual topomap PDFs ---
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
                cfg_t.highlightsize    = 12;
            else
                cfg_t.highlight = 'off';
            end
            ft_topoplotTFR(cfg_t, freq_diff);
            if any(mask_t)
                set(findobj(gca, 'Type', 'line', 'Marker', '*'), 'LineWidth', 1.0);
            end

            t_ms      = round(t * 1000);
            fname_pdf = fullfile(ind_dir, sprintf('%s_%03dms.pdf', band_name, t_ms));
            exportgraphics(fig_tmp, fname_pdf, 'ContentType', 'vector');
            close(fig_tmp);
        end
        fprintf('  [%s] %s: topo PDFs saved\n', cond, band_name);

        % --- colorbar PDF for this band ---
        fig_cb = figure('Visible', 'off', 'Units', 'centimeters', ...
                        'Position', [0, 0, fig_cb_w, fig_cb_h]);
        ax_tmp = axes('Position', [cb_x - 0.001, cb_y, cb_wn, cb_hn], 'Visible', 'off'); %#ok<LAXES>
        colormap(ax_tmp, jet(256));
        set(ax_tmp, 'CLim', zlim_diff, 'CLimMode', 'manual');
        cb2          = colorbar(ax_tmp, 'Location', 'eastoutside');
        cb2.Position = [cb_x, cb_y, cb_wn, cb_hn];
        cb2.FontSize = 18;
        cb2.Ticks    = [zlim_diff(1), 0, zlim_diff(2)];
        cb2.TickLabels = {sprintf('%.1f', zlim_diff(1)), '0', sprintf('%.1f', zlim_diff(2))};
        drawnow;
        fname_cb = fullfile(ind_dir, sprintf('colorbar_%s.pdf', band_name));
        exportgraphics(fig_cb, fname_cb, 'ContentType', 'vector');
        close(fig_cb);
        fprintf('  [%s] %s: colorbar saved\n', cond, band_name);
    end
    fprintf('[%s] %d topo PDFs + %d colorbars -> %s\n', cond, n_bands * n_times, n_bands, ind_dir);
end

disp('Section 4 done.');
