% fig_poster_erp_cbpt.m  [supplemental]
% SVG export of significant ERP clusters for the poster (PowerPoint-ready).
% For each qualified cluster, saves a set (ERP waveform + cluster topomap) and
% the two panels separately, plus a standalone legend.
% Requires stat_erp_cbpt.m (cluster extraction) and stat_rt.m to have been run first.
% Output: result/fig_poster_erp_cbpt/{tag}.svg, {tag}_erp.svg, {tag}_topo.svg, legend.svg
clear;
config;

% Suppress figure pop-ups (also covers figures created inside FieldTrip)
set(0, 'DefaultFigureVisible', 'off');

data_cluster_dir = fullfile(prj_dir, 'result', 'stat_erp_clusters', 'qualified');
data_erp_dir     = fullfile(prj_dir, 'result', 'erp_group_cond');
data_stat_dir    = fullfile(prj_dir, 'result', 'stat_erp_cbpt');
data_rt_dir      = fullfile(prj_dir, 'result', 'stat_rt');
res_dir          = fullfile(prj_dir, 'result', 'fig_poster_erp_cbpt');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

alpha   = 0.05;
font_sz = 18;   % pt
col_exp = [0.00, 0.45, 0.74];
col_nov = [0.85, 0.33, 0.10];
col_sig = [0.85, 0.85, 0.85];

% Layout (cm)
erp_w   = 9.0;   % ERP axes width
erp_h   = 5.5;   % ERP axes height
topo_cm = 5.0;   % topomap size (square)
mrg_l   = 2.6;   % left margin (tick labels + ylabel)
mrg_b   = 1.9;   % bottom margin (tick labels + xlabel)
mrg_t   = 0.3;
mrg_r   = 0.3;
gap     = 0.3;   % ERP-topomap gap
fig_w   = mrg_l + erp_w + gap + topo_cm + mrg_r;
fig_h   = mrg_b + erp_h + mrg_t;

load(fullfile(data_rt_dir, 'stat.mat'));
mean_rt_exp = mean(stat.exp.m_rt);
mean_rt_nov = mean(stat.nov.m_rt);

disp('--- saving poster ERP + topomap SVGs ---');
for ci = 1:length(conditions)
    cond = conditions{ci};

    cfg_avg = []; cfg_avg.keeptrials = 'no';
    load(fullfile(data_erp_dir, ['exp_', cond, '.mat']));
    avg_exp_full = ft_timelockanalysis(cfg_avg, data); clear data;
    load(fullfile(data_erp_dir, ['nov_', cond, '.mat']));
    avg_nov_full = ft_timelockanalysis(cfg_avg, data); clear data;

    load(fullfile(data_stat_dir, [cond, '.mat']));

    for pol_i = 1:2
        if pol_i == 1, pol = 'pos'; clusters = stat.posclusters;
        else,          pol = 'neg'; clusters = stat.negclusters;
        end

        for cli = 1:length(clusters)
            if clusters(cli).prob >= alpha, continue; end

            fpath = fullfile(data_cluster_dir, [cond, '_', pol, '_', num2str(cli), '.mat']);
            if ~exist(fpath, 'file'), continue; end
            load(fpath);

            tag        = sprintf('%s_%s_%d', cond, pol, cli);
            chan_names = data.erp_exp.label;

            cfg_sel = []; cfg_sel.channel = chan_names; cfg_sel.latency = [0.0, 0.5];
            avg_exp_ch = ft_selectdata(cfg_sel, avg_exp_full);
            avg_nov_ch = ft_selectdata(cfg_sel, avg_nov_full);

            erp_e  = mean(avg_exp_ch.avg, 1);
            erp_n  = mean(avg_nov_ch.avg, 1);
            t_erp  = avg_exp_ch.time;
            sig_t  = any(data.mask, 1);
            t_stat = stat.time;

            y_all = [erp_e, erp_n];
            pad_y = 0.15 * range(y_all);
            y_lo  = min(y_all) - pad_y;
            y_hi  = max(y_all) + pad_y;

            % ---- set figure: ERP (left) + topomap (right) ----
            fig = figure('Visible', 'off', 'Units', 'centimeters', ...
                'Position', [0, 0, fig_w, fig_h], 'Color', 'w');
            ax_erp = axes(fig, 'Units', 'centimeters', ...
                'Position', [mrg_l, mrg_b, erp_w, erp_h]);
            hold(ax_erp, 'on');

            d    = diff([false, sig_t(:)', false]);
            ons  = find(d ==  1);
            offs = find(d == -1) - 1;
            for rii = 1:length(ons)
                fill(ax_erp, [t_stat(ons(rii)) t_stat(offs(rii)) t_stat(offs(rii)) t_stat(ons(rii))], ...
                    [y_lo y_lo y_hi y_hi], col_sig, 'EdgeColor', 'none');
            end
            xline(ax_erp, 0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
            yline(ax_erp, 0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
            plot(ax_erp, t_erp, erp_e, 'Color', col_exp, 'LineWidth', 2.0);
            plot(ax_erp, t_erp, erp_n, 'Color', col_nov, 'LineWidth', 2.0);
            if strcmp(cond, 'go')
                xline(ax_erp, mean_rt_exp, '--', 'Color', col_exp, 'LineWidth', 1.0);
                xline(ax_erp, mean_rt_nov, '--', 'Color', col_nov, 'LineWidth', 1.0);
            end
            xlim(ax_erp, [t_erp(1), t_erp(end)]);
            ylim(ax_erp, [y_lo, y_hi]);
            xlabel(ax_erp, 'Time (s)', 'FontSize', font_sz);
            ylabel(ax_erp, 'Amplitude (\muV)', 'FontSize', font_sz);
            set(ax_erp, 'FontSize', font_sz, 'TickDir', 'out', 'Box', 'off');

            % Topomap is drawn in its own figure (FieldTrip manages its axes),
            % then copied into the set figure.
            fig_topo = plot_cluster_topo(stat, chan_names, topo_cm);
            ax_topo  = copyobj(gca(fig_topo), fig);
            set(ax_topo, 'Units', 'centimeters', ...
                'Position', [mrg_l + erp_w + gap, mrg_b + (erp_h - topo_cm)/2, topo_cm, topo_cm]);

            print(fig, '-dsvg', fullfile(res_dir, [tag, '.svg']));

            % ---- ERP panel only ----
            delete(ax_topo);
            fig.Position(3) = mrg_l + erp_w + mrg_r;
            print(fig, '-dsvg', fullfile(res_dir, [tag, '_erp.svg']));
            close(fig);

            % ---- topomap panel only ----
            print(fig_topo, '-dsvg', fullfile(res_dir, [tag, '_topo.svg']));
            close(fig_topo);

            fprintf('  saved: %s\n', tag);
        end
    end
end

%% legend SVG
fig_leg = figure('Visible', 'off', 'Units', 'centimeters', ...
    'Position', [0, 0, 7, 3], 'Color', 'w');
ax_leg = axes(fig_leg, 'Position', [0, 0, 1, 1], 'Visible', 'off');
hold(ax_leg, 'on');
h_e = plot(ax_leg, NaN, NaN, '-', 'Color', col_exp, 'LineWidth', 2.0);
h_n = plot(ax_leg, NaN, NaN, '-', 'Color', col_nov, 'LineWidth', 2.0);
legend(ax_leg, [h_e, h_n], {'Experienced', 'Novice'}, ...
    'Orientation', 'vertical', 'FontSize', font_sz, 'Box', 'off', 'Location', 'best');
print(fig_leg, '-dsvg', fullfile(res_dir, 'legend.svg'));
close(fig_leg);

set(0, 'DefaultFigureVisible', 'on');
fprintf('Saved poster SVGs to:\n  %s\n', res_dir);

%% local functions
function fig_topo = plot_cluster_topo(stat, chan_names, topo_cm)
% Blank topomap with cluster electrodes marked by red circles (own figure).
tmp_stat      = stat;
tmp_stat.stat = zeros(size(stat.stat));
fig_topo = figure('Visible', 'off', 'Units', 'centimeters', ...
    'Position', [0, 0, topo_cm, topo_cm], 'Color', 'w');
cfg_t = [];
cfg_t.parameter          = 'stat';
cfg_t.layout             = 'standard_waveguard64_1005_rotated.elc';
cfg_t.style              = 'blank';
cfg_t.comment            = 'no';
cfg_t.colorbar           = 'no';
cfg_t.markers            = 'on';
cfg_t.markersize         = 3;
cfg_t.highlight          = 'on';
cfg_t.highlightchannel   = chan_names;
cfg_t.highlightsymbol    = 'o';
cfg_t.highlightcolor     = [0.8 0 0];
cfg_t.highlightsize      = 8;
cfg_t.highlightlinewidth = 1.5;
ft_topoplotER(cfg_t, tmp_stat);
% Fill the figure with the topomap axes (removes default margins)
set(gca(fig_topo), 'Position', [0.01, 0.01, 0.98, 0.98]);
end
