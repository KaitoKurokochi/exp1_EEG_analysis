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

%% figure - all-band time overview (5 bands x 11 times, one SVG+PDF per condition)
% Rows:    (a) Theta / (b) Alpha / (c) Beta / (d) Low-gamma / (e) High-gamma
% Columns: 0, 50, 100, ..., 500 ms
% Each cell: Exp - Nov power difference  (* = CBPT significant channels)
clear;
config;

stat_data_dir  = fullfile(prj_dir, 'result', 'stat_freq_cbpt');
freq_data_dir  = fullfile(prj_dir, 'result', 'freq_group_cond');
res_dir        = fullfile(prj_dir, 'result', 'fig_freq_overview_topo');
paper_figs_dir = 'C:\Users\kaito\workspace\exp1_paper\Figs';
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

row_labels = {'(a)', '(b)', '(c)', '(d)', '(e)'};

% layout constants (cm) — aligned with stat_freq_cbpt_alpha.m
topo_sz     = 400;
label_w_cm  = 1.2;   % left: row labels
topo_cm     = 2.96;  % topo cell size
header_h_cm = 0.5;   % top: time labels
pad_b_cm    = 0.1;
row_gap_cm  = 0.50;  % vertical gap between rows
gap_cb_cm   = 0.1;   % gap between topos and colorbar
cb_w_cm     = 0.4;   % colorbar width
pad_r_cm    = 0.8;

% row bottom edges (cm from figure bottom), row 1 at top
row_bottoms_cm = zeros(1, n_bands);
for ri = 1:n_bands
    row_bottoms_cm(ri) = pad_b_cm + (n_bands - ri) * (topo_cm + row_gap_cm);
end

fig_w_cm = label_w_cm + n_times*topo_cm + gap_cb_cm + cb_w_cm + pad_r_cm;
fig_h_cm = header_h_cm + n_bands*topo_cm + (n_bands-1)*row_gap_cm + pad_b_cm;

disp('--- creating 5-band x 11-time overview figures ---');
for ci = 1:length(conditions)
    cond = conditions{ci};

    load(fullfile(freq_data_dir, ['exp_', cond, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(freq_data_dir, ['nov_', cond, '.mat'])); freq_nov = freq; clear freq;

    topo_imgs = cell(n_bands, n_times);

    for ri = 1:n_bands
        zlim_diff = [-vals.mx_abs_diff(ri), vals.mx_abs_diff(ri)];
        s = load(fullfile(stat_data_dir, [cond, '_', bands{ri,2}, '.mat']));

        for ti = 1:n_times
            t = times(ti);

            cfg_sel           = [];
            cfg_sel.frequency = bands{ri, 1};
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
            topo_imgs{ri, ti} = imresize(print(fig_tmp, '-RGBImage'), [topo_sz, topo_sz]);
            close(fig_tmp);
        end
        fprintf('  [%s] band %d/%d done\n', cond, ri, n_bands);
    end

    % assemble composite figure
    fig = figure('Visible', 'off', 'Units', 'centimeters', ...
        'Position', [0, 0, fig_w_cm, fig_h_cm]);

    for ri = 1:n_bands
        row_b = row_bottoms_cm(ri) / fig_h_cm;
        for ti = 1:n_times
            col_l = (label_w_cm + (ti-1)*topo_cm) / fig_w_cm;
            ax = axes('Position', [col_l, row_b, topo_cm/fig_w_cm, topo_cm/fig_h_cm]); %#ok<LAXES>
            image(ax, topo_imgs{ri, ti}); axis(ax, 'image'); axis(ax, 'off');
        end
    end

    % time labels (top header)
    hdr_b = (pad_b_cm + n_bands*topo_cm + (n_bands-1)*row_gap_cm) / fig_h_cm;
    for ti = 1:n_times
        col_l = (label_w_cm + (ti-1)*topo_cm) / fig_w_cm;
        annotation(fig, 'textbox', [col_l, hdr_b, topo_cm/fig_w_cm, header_h_cm/fig_h_cm], ...
            'String', sprintf('%d ms', round(times(ti)*1000)), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 18);
    end

    % row labels (left, horizontal, bold)
    for ri = 1:n_bands
        row_b = row_bottoms_cm(ri) / fig_h_cm;
        annotation(fig, 'textbox', [0, row_b, label_w_cm/fig_w_cm, topo_cm/fig_h_cm], ...
            'String', row_labels{ri}, ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 18, 'FontWeight', 'bold');
    end

    % colorbars (one per row, on the right)
    cb_l     = (label_w_cm + n_times*topo_cm + gap_cb_cm) / fig_w_cm;
    offset_n = 0.001;
    for ri = 1:n_bands
        zlim_diff = [-vals.mx_abs_diff(ri), vals.mx_abs_diff(ri)];
        row_b = row_bottoms_cm(ri) / fig_h_cm;
        ax_cb = axes('Position', [cb_l - offset_n, row_b, cb_w_cm/fig_w_cm, topo_cm/fig_h_cm], 'Visible', 'off'); %#ok<LAXES>
        colormap(ax_cb, jet(256)); clim(ax_cb, zlim_diff);
        cb = colorbar(ax_cb, 'Location', 'eastoutside');
        cb.Position = [cb_l, row_b, cb_w_cm/fig_w_cm, topo_cm/fig_h_cm];
        cb.FontSize = 18;
    end

    % save SVG
    out_svg = fullfile(res_dir, [cond, '_all_bands.svg']);
    print(fig, '-dsvg', out_svg);
    fprintf('Saved SVG: %s\n', out_svg);

    % save PDF (vector)
    out_pdf = fullfile(res_dir, [cond, '_all_bands.pdf']);
    exportgraphics(fig, out_pdf, 'ContentType', 'vector');
    fprintf('Saved PDF: %s\n', out_pdf);

    % copy PDF to exp1_paper/Figs/
    dest_pdf = fullfile(paper_figs_dir, [cond, '_all_bands.pdf']);
    copyfile(out_pdf, dest_pdf);
    fprintf('Copied PDF to: %s\n', dest_pdf);

    close(fig);
end

disp('Done.');
