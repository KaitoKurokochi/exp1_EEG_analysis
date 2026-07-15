% make_fig6_alpha.m
% Standalone figure-generation script for Figure 6 (alpha-band topographies).
% Skips statistics (pre-computed); loads results from stat_freq_cbpt_alpha/.
% Outputs SVG and PDF to result/fig_freq_alpha_topo/, then copies PDF to
% exp1_paper/Figs/alpha_6row_topo.pdf.

clear;
config;

stat_data_dir = fullfile(prj_dir, 'result', 'stat_freq_cbpt_alpha');
freq_data_dir = fullfile(prj_dir, 'result', 'freq_group_cond_alpha');
res_dir       = fullfile(prj_dir, 'result', 'fig_freq_alpha_topo');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

paper_figs_dir = 'C:\Users\kaito\workspace\exp1_paper\Figs';

band_freq = [7 13];
band_name = 'alpha';
times     = 0:0.05:0.5;
n_times   = length(times);

% 6-row definition
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
label_w_cm  = 1.2;
topo_cm     = 2.96;
header_h_cm = 0.5;
pad_b_cm    = 0.1;
row_gap_cm  = 0.50;
gap_cb_cm   = 0.1;
cb_w_cm     = 0.4;
pad_r_cm    = 0.8;

% row bottom edges (cm from figure bottom)
row_bottoms_cm = zeros(1, n_rows);
for ri = 1:n_rows
    row_bottoms_cm(ri) = pad_b_cm + (n_rows - ri) * (topo_cm + row_gap_cm);
end

fig_w_cm = label_w_cm + n_times*topo_cm + gap_cb_cm + cb_w_cm + pad_r_cm;
fig_h_cm = header_h_cm + n_rows*topo_cm + (n_rows-1)*row_gap_cm + pad_b_cm;

% compute color limits
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

% pre-load freq data and stat
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
        % Save individual topomap as vector PDF before rasterising for the composite
        t_ms      = round(t * 1000);
        fname_pdf = fullfile(ind_dir, sprintf('%s_%03dms.pdf', row_names{ri}, t_ms));
        exportgraphics(fig_tmp, fname_pdf, 'ContentType', 'vector');
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

% row labels (left, horizontal, bold)
for ri = 1:n_rows
    row_b = row_bottoms_cm(ri) / fig_h_cm;
    annotation(fig, 'textbox', [0, row_b, label_w_cm/fig_w_cm, topo_cm/fig_h_cm], ...
        'String', row_cfg(ri).label, ...
        'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 18, 'FontWeight', 'bold');
end

% colorbars
cb_l = (label_w_cm + n_times*topo_cm + gap_cb_cm) / fig_w_cm;
offset_n = 0.001;
for ri = 1:n_rows
    row_b = row_bottoms_cm(ri) / fig_h_cm;
    ax_cb = axes('Position', [cb_l - offset_n, row_b, cb_w_cm/fig_w_cm, topo_cm/fig_h_cm], 'Visible', 'off'); %#ok<LAXES>
    colormap(ax_cb, jet(256)); clim(ax_cb, zlims_row{ri});
    cb = colorbar(ax_cb, 'Location', 'eastoutside');
    cb.Position = [cb_l, row_b, cb_w_cm/fig_w_cm, topo_cm/fig_h_cm];
    cb.FontSize = 18;
end

% save SVG
out_svg = fullfile(res_dir, 'alpha_6row_topo.svg');
print(fig, '-dsvg', out_svg);
fprintf('Saved SVG: %s\n', out_svg);

% save PDF (vector)
out_pdf = fullfile(res_dir, 'alpha_6row_topo.pdf');
exportgraphics(fig, out_pdf, 'ContentType', 'vector');
fprintf('Saved PDF: %s\n', out_pdf);

% copy PDF to exp1_paper/Figs/
dest_pdf = fullfile(paper_figs_dir, 'alpha_6row_topo.pdf');
copyfile(out_pdf, dest_pdf);
fprintf('Copied PDF to: %s\n', dest_pdf);

close(fig);

% save colorbars as PDF (vector), sized to match the composite figure's colorbar
disp('--- saving colorbar PDFs ---');
cb_tags_v   = {'grp',    'diff'};
zlims_cb_v  = {zlim_grp, zlim_diff};
cb_tick_cm  = 1.00;   % space for tick labels to the right of the bar
cb_pad_l_cm = 0.20;   % left padding
cb_pad_r_cm = 0.20;   % right padding (prevent label clipping)
cb_pad_v_cm = 0.30;   % top/bottom padding
fig_cb_w    = cb_pad_l_cm + cb_w_cm + cb_tick_cm + cb_pad_r_cm;
fig_cb_h    = topo_cm + 2*cb_pad_v_cm;
cb_xn       = cb_pad_l_cm / fig_cb_w;
cb_wn       = cb_w_cm     / fig_cb_w;
cb_yn       = cb_pad_v_cm / fig_cb_h;
cb_hn       = topo_cm     / fig_cb_h;
for k = 1:2
    fig_cb = figure('Visible', 'off', 'Units', 'centimeters', ...
                    'Position', [0, 0, fig_cb_w, fig_cb_h]);
    ax_tmp = axes('Position', [cb_xn - 0.001, cb_yn, cb_wn, cb_hn], 'Visible', 'off'); %#ok<LAXES>
    colormap(ax_tmp, jet(256));
    set(ax_tmp, 'CLim', zlims_cb_v{k}, 'CLimMode', 'manual');
    cb2          = colorbar(ax_tmp, 'Location', 'eastoutside');
    cb2.Position = [cb_xn, cb_yn, cb_wn, cb_hn];
    cb2.FontSize = 18;
    cb2.Ticks      = [zlims_cb_v{k}(1), 0, zlims_cb_v{k}(2)];
    cb2.TickLabels = {sprintf('%.1f', zlims_cb_v{k}(1)), '0', sprintf('%.1f', zlims_cb_v{k}(2))};
    drawnow;
    fname_cb = fullfile(ind_dir, sprintf('colorbar_%s.pdf', cb_tags_v{k}));
    exportgraphics(fig_cb, fname_cb, 'ContentType', 'vector');
    close(fig_cb);
    fprintf('  saved colorbar: %s\n', cb_tags_v{k});
end
fprintf('Saved %d individual topomap PDFs + 2 colorbar PDFs to:\n  %s\n', n_rows * n_times, ind_dir);

disp('Done.');
