% stat_freq_cbpt_alpha.m
% Spatio-temporal CBPT for alpha band only (7-13 Hz).
% Data source: result/freq_group_cond_alpha/ (alpha-limited wavelet output).
% Saves stat results to result/stat_freq_cbpt_alpha/ and a composite SVG
% (2 rows [Go / NoGo] x 11 time points) to result/fig_freq_alpha_topo/.

%% statistics
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'freq_group_cond_alpha');
res_dir  = fullfile(prj_dir, 'result', 'stat_freq_cbpt_alpha');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(prj_dir, 'src', 'neighbours.mat'));

band_freq = [7 13];
band_name = 'alpha';

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

%% save individual topomap PDFs (vector, Illustrator-ready)
% Saves each row x time topomap as a separate PDF to
% result/fig_freq_alpha_topo/individual/.
% Individual PDFs are assembled into the final figure in Illustrator.
% Freq/stat data are reloaded to enable vector re-rendering via
% ft_topoplotTFR -> exportgraphics (ContentType=vector).

clear;
config;
res_dir = fullfile(prj_dir, 'result', 'fig_freq_alpha_topo');
times   = 0:0.05:0.5;
n_times = length(times);
topo_sz = 400;

row_cfg(1) = struct('cond', 'go',   'group', 'exp',  'label', '(a)');
row_cfg(2) = struct('cond', 'go',   'group', 'nov',  'label', '(b)');
row_cfg(3) = struct('cond', 'go',   'group', 'diff', 'label', '(c)');
row_cfg(4) = struct('cond', 'nogo', 'group', 'exp',  'label', '(d)');
row_cfg(5) = struct('cond', 'nogo', 'group', 'nov',  'label', '(e)');
row_cfg(6) = struct('cond', 'nogo', 'group', 'diff', 'label', '(f)');
n_rows     = length(row_cfg);

band_freq     = [7 13];
band_name     = 'alpha';
stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt_alpha');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond_alpha');

% ---- compute color limits across all conditions x times ----
disp('--- computing color limits ---');
mx_abs_grp  = 0;
mx_abs_diff = 0;
for ci = 1:length(conditions)
    cond = conditions{ci};
    load(fullfile(freq_data_dir, ['exp_', cond, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(freq_data_dir, ['nov_', cond, '.mat'])); freq_nov = freq; clear freq;
    for ti = 1:n_times
        t = times(ti);
        cfg_sel = []; cfg_sel.frequency = band_freq; cfg_sel.latency = [t-0.001, t+0.001];
        cfg_avg = []; cfg_avg.keeptrials = 'no';
        avg_exp = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
        avg_nov = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
        mx_abs_grp = max(mx_abs_grp, max(abs(avg_exp.powspctrm(:))));
        mx_abs_grp = max(mx_abs_grp, max(abs(avg_nov.powspctrm(:))));
        cfg_math = []; cfg_math.operation = 'x1 - x2'; cfg_math.parameter = 'powspctrm';
        d = ft_math(cfg_math, avg_exp, avg_nov);
        mx_abs_diff = max(mx_abs_diff, max(abs(d.powspctrm(:))));
    end
end
zlim_grp  = [-mx_abs_grp,  mx_abs_grp];
zlim_diff = [-mx_abs_diff, mx_abs_diff];
fprintf('zlim Exp/Nov: [%.4f, %.4f]\n', zlim_grp(1),  zlim_grp(2));
fprintf('zlim Diff:    [%.4f, %.4f]\n', zlim_diff(1), zlim_diff(2));

zlims_row = cell(1, n_rows);
for ri = 1:n_rows
    if strcmp(row_cfg(ri).group, 'diff')
        zlims_row{ri} = zlim_diff;
    else
        zlims_row{ri} = zlim_grp;
    end
end

% ---- always reload freq/stat data for vector re-rendering ----
disp('--- loading freq/stat data ---');
freq_data = struct();
stat_data = struct();
for ci = 1:length(conditions)
    cond = conditions{ci};
    tmp_exp = load(fullfile(freq_data_dir, ['exp_', cond, '.mat']));
    tmp_nov = load(fullfile(freq_data_dir, ['nov_', cond, '.mat']));
    freq_data.(cond).exp = tmp_exp.freq;
    freq_data.(cond).nov = tmp_nov.freq;
    stat_data.(cond) = load(fullfile(stat_data_dir, [cond, '_', band_name, '.mat']));
end

ind_dir   = fullfile(res_dir, 'individual');
if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end
row_names = arrayfun(@(r) sprintf('%s_%s', r.cond, r.group), row_cfg, 'UniformOutput', false);

disp('--- saving individual topomap PDFs ---');
for ri = 1:n_rows
    cond  = row_cfg(ri).cond;
    group = row_cfg(ri).group;
    freq_exp = freq_data.(cond).exp;
    freq_nov = freq_data.(cond).nov;
    s        = stat_data.(cond);

    for ti = 1:n_times
        t = times(ti);
        cfg_sel = []; cfg_sel.frequency = band_freq; cfg_sel.latency = [t-0.001, t+0.001];
        cfg_avg = []; cfg_avg.keeptrials = 'no';
        avg_exp  = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
        avg_nov  = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
        cfg_math = []; cfg_math.operation = 'x1 - x2'; cfg_math.parameter = 'powspctrm';
        avg_diff = ft_math(cfg_math, avg_exp, avg_nov);

        switch group
            case 'exp',  plot_data = avg_exp;
            case 'nov',  plot_data = avg_nov;
            case 'diff', plot_data = avg_diff;
        end

        [~, t_idx] = min(abs(s.stat.time - t));
        mask_t = s.stat.mask(:, t_idx);

        fig_tmp = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 topo_sz topo_sz]);
        cfg_t = []; cfg_t.colorbar = 'no'; cfg_t.layout = 'standard_waveguard64_1005_rotated.elc';
        cfg_t.colormap = 'jet'; cfg_t.zlim = zlims_row{ri};
        cfg_t.comment = 'no'; cfg_t.title = ' ';
        if strcmp(group, 'diff') && any(mask_t)
            cfg_t.highlight        = 'on';
            cfg_t.highlightchannel = find(mask_t);
            cfg_t.highlightsymbol  = '*';
            cfg_t.highlightcolor   = [0 0 0];
            cfg_t.highlightsize    = 12;
        else
            cfg_t.highlight = 'off';
        end
        ft_topoplotTFR(cfg_t, plot_data);
        if strcmp(group, 'diff') && any(mask_t)
            set(findobj(gca, 'Type', 'line', 'Marker', '*'), 'LineWidth', 1.0);
        end

        t_ms      = round(t * 1000);
        fname_pdf = fullfile(ind_dir, sprintf('%s_%03dms.pdf', row_names{ri}, t_ms));
        exportgraphics(fig_tmp, fname_pdf, 'ContentType', 'vector');
        close(fig_tmp);
    end
    fprintf('  row %d (%s %s) saved\n', ri, cond, group);
end

fprintf('Saved %d individual topomap PDFs to:\n  %s\n', n_rows * n_times, ind_dir);

%% save colorbar PDFs (vector, Illustrator-ready)
% Saves colorbar_grp.pdf and colorbar_diff.pdf to
% result/fig_freq_alpha_topo/individual/.
% topo_cm_cb (2.96) must match topo_sz used in the topomap section above.
% CB_PDF_W and CB_PDF_H in arrange_topomaps.jsx must match fig_cb_w / fig_cb_h.

clear;
config;
ind_dir       = fullfile(prj_dir, 'result', 'fig_freq_alpha_topo', 'individual');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond_alpha');
if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end

band_freq = [7 13];
times     = 0:0.05:0.5;
n_times   = length(times);

% ---- compute color limits ----
disp('--- computing color limits ---');
mx_abs_grp  = 0;
mx_abs_diff = 0;
for ci = 1:length(conditions)
    cond = conditions{ci};
    load(fullfile(freq_data_dir, ['exp_', cond, '.mat'])); freq_exp = freq; clear freq;
    load(fullfile(freq_data_dir, ['nov_', cond, '.mat'])); freq_nov = freq; clear freq;
    for ti = 1:n_times
        t = times(ti);
        cfg_sel = []; cfg_sel.frequency = band_freq; cfg_sel.latency = [t-0.001, t+0.001];
        cfg_avg = []; cfg_avg.keeptrials = 'no';
        avg_exp = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_exp));
        avg_nov = ft_freqdescriptives(cfg_avg, ft_selectdata(cfg_sel, freq_nov));
        mx_abs_grp = max(mx_abs_grp, max(abs(avg_exp.powspctrm(:))));
        mx_abs_grp = max(mx_abs_grp, max(abs(avg_nov.powspctrm(:))));
        cfg_math = []; cfg_math.operation = 'x1 - x2'; cfg_math.parameter = 'powspctrm';
        d = ft_math(cfg_math, avg_exp, avg_nov);
        mx_abs_diff = max(mx_abs_diff, max(abs(d.powspctrm(:))));
    end
end
zlim_grp  = [-mx_abs_grp,  mx_abs_grp];
zlim_diff = [-mx_abs_diff, mx_abs_diff];
fprintf('zlim Exp/Nov: [%.4f, %.4f]\n', zlim_grp(1),  zlim_grp(2));
fprintf('zlim Diff:    [%.4f, %.4f]\n', zlim_diff(1), zlim_diff(2));

% ---- colorbar layout parameters ----
cb_font_sz = 18;
cb_tags    = {'grp',           'diff'};
% Literal Unicode Δ exported as '#' in the PDF; '\Delta' (tex) fixed it.
cb_labels     = {'Power (dB)',    '\DeltaPower (dB)'};
cb_label_lens = {10,              11};  % rendered length, for padding calc
zlims_cb   = {zlim_grp,        zlim_diff};
topo_cm_cb = 2.96;   % must match topo_sz rendering in topomap section
cb_w_cm    = 0.40;   % colorbar bar width
tick_cm    = 1.00;   % space for tick labels
label_w_cm = 0.70;   % space for rotated axis label
pad_l_cm   = 0.20;   % left padding
pad_r_cm   = 0.20;   % right padding
pad_v_cm   = 0.30;   % minimum top/bottom padding
fig_cb_w   = pad_l_cm + cb_w_cm + tick_cm + label_w_cm + pad_r_cm;
% char_w_cm approximates character width at cb_font_sz pt (rotated 270 deg
% label maps string length to the vertical direction).
char_w_cm  = cb_font_sz * 0.60 / 28.3465;
% Per-colorbar bottom padding is computed individually so that the rotated
% label never extends below y=0 in the figure.  The bar center sits at
% eff_pad_v_cm + topo_cm_cb/2 from the figure bottom.
% Width-only normalised positions (constant across colorbars):
cb_x  = pad_l_cm / fig_cb_w;
cb_wn = cb_w_cm  / fig_cb_w;

disp('--- saving colorbar PDFs ---');
for k = 1:2
    lbl_half_cm  = cb_label_lens{k} * char_w_cm / 2;
    % Ensure label bottom (= bar_center - lbl_half) >= 0
    eff_pad_v_cm = max(pad_v_cm, lbl_half_cm - topo_cm_cb/2);
    % Figure height: label top + top padding
    %   label top = eff_pad_v_cm + topo_cm_cb/2 + lbl_half_cm
    fig_cb_h_k   = eff_pad_v_cm + topo_cm_cb/2 + lbl_half_cm + pad_v_cm;
    cb_y_k  = eff_pad_v_cm  / fig_cb_h_k;
    cb_hn_k = topo_cm_cb / fig_cb_h_k;

    fig_cb = figure('Visible', 'off', 'Units', 'centimeters', ...
                    'Position', [0, 0, fig_cb_w, fig_cb_h_k]);
    ax_tmp = axes('Position', [cb_x - 0.001, cb_y_k, cb_wn, cb_hn_k], 'Visible', 'off'); %#ok<LAXES>
    colormap(ax_tmp, jet(256));
    set(ax_tmp, 'CLim', zlims_cb{k}, 'CLimMode', 'manual');
    cb2                = colorbar(ax_tmp, 'Location', 'eastoutside');
    cb2.Position       = [cb_x, cb_y_k, cb_wn, cb_hn_k];
    cb2.FontSize        = cb_font_sz;
    cb2.Ticks           = [zlims_cb{k}(1), 0, zlims_cb{k}(2)];
    cb2.TickLabels      = {sprintf('%.1f', zlims_cb{k}(1)), '0', sprintf('%.1f', zlims_cb{k}(2))};
    cb2.Label.String      = cb_labels{k};
    cb2.Label.Interpreter = 'tex';
    cb2.Label.FontSize    = cb_font_sz;
    cb2.Label.Rotation    = 270;
    drawnow;
    fname_cb = fullfile(ind_dir, sprintf('colorbar_%s.pdf', cb_tags{k}));
    exportgraphics(fig_cb, fname_cb, 'ContentType', 'vector');
    close(fig_cb);
    fprintf('  saved: %s\n', cb_tags{k});
end
fprintf('Saved 2 colorbar PDFs to:\n  %s\n', ind_dir);
