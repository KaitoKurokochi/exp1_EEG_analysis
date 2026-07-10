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

%% figure - one SVG with 6 rows (Exp Go / Nov Go / Diff Go / Exp NoGo / Nov NoGo / Diff NoGo)
clear;
config;

stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt_alpha');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond_alpha');
res_dir       = fullfile(prj_dir, 'result', 'fig_freq_alpha_topo');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

band_freq = [7 13];
band_name = 'alpha';
times     = 0:0.05:0.5;
n_times   = length(times);

% 6-row definition: cond (go/nogo, must match conditions in config.m), group (exp/nov/diff), label (a)-(f)
% Note: variable is named row_cfg (not rows) to avoid clash with MATLAB R2021a+ built-in rows().
row_cfg(1) = struct('cond', 'go',   'group', 'exp',  'label', '(a)');
row_cfg(2) = struct('cond', 'go',   'group', 'nov',  'label', '(b)');
row_cfg(3) = struct('cond', 'go',   'group', 'diff', 'label', '(c)');
row_cfg(4) = struct('cond', 'nogo', 'group', 'exp',  'label', '(d)');
row_cfg(5) = struct('cond', 'nogo', 'group', 'nov',  'label', '(e)');
row_cfg(6) = struct('cond', 'nogo', 'group', 'diff', 'label', '(f)');
n_rows     = length(row_cfg);

% layout constants (cm)
topo_sz     = 400;
label_w_cm  = 1.2;   % left: row labels
topo_cm     = 2.96;  % topo cell size (maximised)
header_h_cm = 0.5;   % top: time labels
pad_b_cm    = 0.1;
row_gap_cm  = 0.50;  % vertical gap between rows
gap_cb_cm   = 0.1;   % gap between topos and colorbar
cb_w_cm     = 0.4;   % colorbar width
pad_r_cm    = 0.8;

% row bottom edges (cm from figure bottom), row 1 at top
row_bottoms_cm = zeros(1, n_rows);
for ri = 1:n_rows
    row_bottoms_cm(ri) = pad_b_cm + (n_rows - ri) * (topo_cm + row_gap_cm);
end

fig_w_cm = label_w_cm + n_times*topo_cm + gap_cb_cm + cb_w_cm + pad_r_cm;
fig_h_cm = header_h_cm + n_rows*topo_cm + (n_rows-1)*row_gap_cm + pad_b_cm;

% compute color limits across all conditions x times
disp('--- computing color limits ---');
mx_abs_grp  = 0;   % Exp and Nov shared scale
mx_abs_diff = 0;   % Diff scale
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

% zlims per row: exp/nov rows use zlim_grp, diff rows use zlim_diff
zlims_row = cell(1, n_rows);
for ri = 1:n_rows
    if strcmp(row_cfg(ri).group, 'diff')
        zlims_row{ri} = zlim_diff;
    else
        zlims_row{ri} = zlim_grp;
    end
end

% pre-load freq data and stat for both conditions
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

disp('--- rendering 6-row figure ---');
imgs = cell(n_rows, n_times);

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
        cfg_t = []; cfg_t.colorbar = 'no'; cfg_t.layout = 'easycapM11.mat';
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
        imgs{ri, ti} = imresize(print(fig_tmp, '-RGBImage'), [topo_sz, topo_sz]);
        close(fig_tmp);
    end
    fprintf('  row %d (%s %s) rendered\n', ri, cond, group);
end

% assemble figure
fig = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [0, 0, fig_w_cm, fig_h_cm]);

for ri = 1:n_rows
    row_b = row_bottoms_cm(ri) / fig_h_cm;
    for ti = 1:n_times
        col_l = (label_w_cm + (ti-1)*topo_cm) / fig_w_cm;
        ax = axes('Position', [col_l, row_b, topo_cm/fig_w_cm, topo_cm/fig_h_cm]); %#ok<LAXES>
        image(ax, imgs{ri, ti}); axis(ax, 'image'); axis(ax, 'off');
    end
end

% time labels (top header)
hdr_b = (pad_b_cm + n_rows*topo_cm + (n_rows-1)*row_gap_cm) / fig_h_cm;
for ti = 1:n_times
    col_l = (label_w_cm + (ti-1)*topo_cm) / fig_w_cm;
    annotation(fig, 'textbox', [col_l, hdr_b, topo_cm/fig_w_cm, header_h_cm/fig_h_cm], ...
        'String', sprintf('%d ms', round(times(ti)*1000)), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', 18);
end

% row labels (left, horizontal, bold 14pt)
for ri = 1:n_rows
    row_b = row_bottoms_cm(ri) / fig_h_cm;
    annotation(fig, 'textbox', [0, row_b, label_w_cm/fig_w_cm, topo_cm/fig_h_cm], ...
        'String', row_cfg(ri).label, ...
        'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 18, 'FontWeight', 'bold');
end

% colorbars (one per row, on the right)
% ax_cb is placed slightly to the LEFT of the colorbar strip so that
% MATLAB renders the tick labels on the RIGHT side of the colorbar.
cb_l = (label_w_cm + n_times*topo_cm + gap_cb_cm) / fig_w_cm;
offset_n = 0.001;   % small leftward offset in normalised units
for ri = 1:n_rows
    row_b = row_bottoms_cm(ri) / fig_h_cm;
    ax_cb = axes('Position', [cb_l - offset_n, row_b, cb_w_cm/fig_w_cm, topo_cm/fig_h_cm], 'Visible', 'off'); %#ok<LAXES>
    colormap(ax_cb, jet(256)); clim(ax_cb, zlims_row{ri});
    cb = colorbar(ax_cb, 'Location', 'eastoutside');
    cb.Position = [cb_l, row_b, cb_w_cm/fig_w_cm, topo_cm/fig_h_cm];
    cb.FontSize = 18;
end

out_path = fullfile(res_dir, 'alpha_6row_topo.svg');
print(fig, '-dsvg', out_path);
close(fig);
fprintf('Saved: %s\n', out_path);

disp('Done.');

%% save individual topomap images
% Saves each row x time topomap as a separate PNG (white borders cropped)
% and colorbars (grp scale / diff scale) to result/fig_freq_alpha_topo/individual/.
%
% NOTE: imgs, zlim_grp, and zlim_diff must already be in the workspace.
%       Run the figure section above first if starting fresh.

% Re-define constants so this section can run after the figure section
% even if the workspace was partially cleared.
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

disp('--- saving individual topomap images ---');

ind_dir = fullfile(res_dir, 'individual');
if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end

% filename prefix per row: '{cond}_{group}'
row_names = arrayfun(@(r) sprintf('%s_%s', r.cond, r.group), row_cfg, 'UniformOutput', false);

for ri = 1:n_rows
    for ti = 1:n_times
        img = imgs{ri, ti};

        % crop leading/trailing pixel rows and columns that are entirely white
        gray  = double(mean(img, 3));
        r_idx = find(~all(gray > 250, 2));   % pixel rows with non-white content
        c_idx = find(~all(gray > 250, 1));   % pixel columns with non-white content
        if ~isempty(r_idx) && ~isempty(c_idx)
            img_crop = img(r_idx(1):r_idx(end), c_idx(1):c_idx(end), :);
        else
            img_crop = img;
        end

        t_ms      = round(times(ti) * 1000);
        fname_img = fullfile(ind_dir, sprintf('%s_%03dms.png', row_names{ri}, t_ms));
        imwrite(img_crop, fname_img);
    end
    fprintf('  row %d (%s) saved\n', ri, row_names{ri});
end

% save colorbars: grp scale (exp/nov rows) and diff scale (diff rows)
cb_tags  = {'grp',    'diff'};
zlims_cb = {zlim_grp, zlim_diff};
for k = 1:2
    fig_cb = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 100 topo_sz]);
    ax_tmp = axes('Position', [0.05 0.05 0.01 0.9]);
    Z      = linspace(zlims_cb{k}(1), zlims_cb{k}(2), 256)';
    imagesc(ax_tmp, Z);
    colormap(ax_tmp, jet(256));
    clim(ax_tmp, zlims_cb{k});
    set(ax_tmp, 'Visible', 'off');
    cb2          = colorbar(ax_tmp, 'Location', 'eastoutside');
    cb2.FontSize = 18;
    cb2.Position = [0.30 0.05 0.45 0.90];
    fname_cb = fullfile(ind_dir, sprintf('colorbar_%s.png', cb_tags{k}));
    print(fig_cb, '-dpng', '-r150', fname_cb);
    close(fig_cb);
    fprintf('  saved colorbar: %s\n', cb_tags{k});
end

fprintf('Saved %d individual topomap images + 2 colorbars to:\n  %s\n', n_rows * n_times, ind_dir);
