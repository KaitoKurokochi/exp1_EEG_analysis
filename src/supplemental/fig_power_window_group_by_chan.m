% fig_power_window_group_by_chan.m
% Per-channel power spectrum comparison across window lengths, shown separately
% for Novices and Experts. Saves one PNG per channel.
%
% Method: ft_freqanalysis (method='mtmfft', taper='boxcar', keeptrials='no').
% Each trial is FFT-ed over the selected time window; results are averaged
% across trials. This is NOT Welch's method (no within-trial segment overlap).
% Output unit: muV^2/Hz.
%
% Window lengths and FFT frequency resolutions:
%   0.5 s -> delta_f = 2.00 Hz   (time range: 0 to +500 ms)
%   1.0 s -> delta_f = 1.00 Hz   (time range: 0 to +1000 ms)
%   1.5 s -> delta_f = 0.67 Hz   (full epoch: -500 to +1000 ms)
%
% This script differs from fig_power_window_by_chan.m in that groups are
% shown separately, enabling simultaneous inspection of window-length effects
% and group differences in spectral power.
%
% Data source: result/erp_group_cond/   (Correct Go + Correct NoGo pooled)
% Output:      result/fig_power_window_group_by_chan/

clear;
config;

% ================================================================
% Settings
% ================================================================
foi_range  = [1 40];  % Hz

% Window definitions: {[t_start_s, t_end_s], label}
win_def = {
    [0.00, 0.50],  '0.5 s (df=2.0 Hz)';
    [0.00, 1.00],  '1.0 s (df=1.0 Hz)';
    [-0.50, 1.00], '1.5 s (df=0.67 Hz)';
};
n_win      = size(win_def, 1);
win_colors = {[0.2, 0.6, 0.2], [0.85, 0.33, 0.10], [0.00, 0.45, 0.74]};

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'fig_power_window_group_by_chan');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ================================================================
% Compute power spectrum for each group x window length
%   pow_gw{gi, wi} = freq struct  (powspctrm: [n_chan x n_freq])
% ================================================================
n_g    = length(groups);
pow_gw = cell(n_g, n_win);

for gi = 1:n_g
    grp = groups{gi};

    % Pool all correct trials (Go + NoGo) for this group
    data_grp = [];
    for ci = 1:length(conditions)
        fname = fullfile(data_dir, [grp, '_', conditions{ci}, '.mat']);
        fprintf('Loading %s_%s ... ', grp, conditions{ci});
        load(fname);  % loads 'data'
        fprintf('%d trials\n', length(data.trial));
        if isempty(data_grp)
            data_grp = data;
        else
            data_grp = ft_appenddata([], data_grp, data);
        end
    end
    fprintf('%s: total %d trials\n', grp, length(data_grp.trial));

    for wi = 1:n_win
        t_start = win_def{wi, 1}(1);
        t_end   = win_def{wi, 1}(2);

        cfg_sel         = [];
        cfg_sel.latency = [t_start, t_end];
        data_win        = ft_selectdata(cfg_sel, data_grp);

        cfg_f            = [];
        cfg_f.method     = 'mtmfft';
        cfg_f.taper      = 'boxcar';
        cfg_f.output     = 'pow';      % muV^2/Hz
        cfg_f.keeptrials = 'no';
        cfg_f.foilim     = foi_range;
        pow_gw{gi, wi}   = ft_freqanalysis(cfg_f, data_win);

        fprintf('  %s — %s: df = %.3f Hz\n', grp, win_def{wi, 2}, ...
                pow_gw{gi, wi}.freq(2) - pow_gw{gi, wi}.freq(1));
    end
end

% ================================================================
% Identify group panel order: Novices (left) | Experts (right)
% ================================================================
nov_gi = find(strcmp(groups, 'nov'));
exp_gi = find(strcmp(groups, 'exp'));
panel_order  = [nov_gi, exp_gi];
panel_titles = {'Novices', 'Experts'};

chan_labels = pow_gw{1, 1}.label;
n_chan      = length(chan_labels);
fprintf('\nRendering %d figures...\n', n_chan);

% ================================================================
% Plot one figure per channel
%   Layout: 1 x 2  (Novices | Experts)
%   Each subplot: 3 window lengths overlaid
% ================================================================
for chi = 1:n_chan
    ch_name = chan_labels{chi};

    % Shared y-limits across both groups and all windows
    y_all = [];
    for gi_tmp = 1:n_g
        for wi = 1:n_win
            y_all = [y_all, pow_gw{gi_tmp, wi}.powspctrm(chi, :)]; %#ok<AGROW>
        end
    end
    y_pad = (max(y_all) - min(y_all)) * 0.08;
    if y_pad == 0, y_pad = 0.01; end
    y_lim = [max(0, min(y_all) - y_pad), max(y_all) + y_pad];

    fig = figure('Units', 'centimeters', 'Position', [2, 2, 24, 9], 'Visible', 'off');

    for pi = 1:2
        gi = panel_order(pi);
        subplot(1, 2, pi);
        hold on;

        for wi = 1:n_win
            pow = pow_gw{gi, wi}.powspctrm(chi, :);
            frq = pow_gw{gi, wi}.freq;
            col = win_colors{wi};
            lbl = win_def{wi, 2};
            plot(frq, pow, '-', 'Color', col, 'LineWidth', 1.6, ...
                 'DisplayName', lbl);
        end

        % Alpha band highlight
        patch([7 13 13 7], [y_lim(1) y_lim(1) y_lim(2) y_lim(2)], ...
              [0.9 0.9 0.6], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
              'HandleVisibility', 'off');
        text(10, y_lim(2) * 0.92, '\alpha', ...
             'HorizontalAlignment', 'center', 'FontSize', 10);

        xlabel('Frequency (Hz)');
        ylabel('\muV^2/Hz');
        title(panel_titles{pi});
        xlim(foi_range);
        ylim(y_lim);
        legend('show', 'Location', 'northeast', 'FontSize', 8);
        grid on; box on;
    end

    sgtitle(['Power spectrum window comparison (\muV^2/Hz) — ', ch_name, ...
             ' (boxcar taper, Novices vs Experts)']);

    saveas(fig, fullfile(res_dir, ['power_wgroup_', ch_name, '.png']));
    close(fig);

    if mod(chi, 10) == 0
        fprintf('  %d / %d done\n', chi, n_chan);
    end
end

fprintf('Done. %d figures saved to:\n  %s\n', n_chan, res_dir);
