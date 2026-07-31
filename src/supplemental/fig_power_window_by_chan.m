% fig_power_window_by_chan.m
% Per-channel power spectrum comparison across three analysis window lengths.
% Saves one PNG per channel to result/fig_power_window_by_chan/.
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
% All correct trials (Go + NoGo, both groups pooled) are used for the
% purpose of this diagnostic visualization.
%
% Data source: result/erp_group_cond/
% Output:      result/fig_power_window_by_chan/

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
res_dir  = fullfile(prj_dir, 'result', 'fig_power_window_by_chan');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ================================================================
% Pool ALL correct trials across both groups (diagnostic purpose)
% ================================================================
fprintf('Loading erp_group_cond data (all groups and conditions)...\n');
data_all = [];

for gi = 1:length(groups)
    for ci = 1:length(conditions)
        fname = fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat']);
        fprintf('  %s_%s ... ', groups{gi}, conditions{ci});
        load(fname);  % loads 'data'
        fprintf('%d trials\n', length(data.trial));
        if isempty(data_all)
            data_all = data;
        else
            data_all = ft_appenddata([], data_all, data);
        end
    end
end

fprintf('Total: %d trials\n\n', length(data_all.trial));

% ================================================================
% Compute power spectrum for each window length
%   pow_win{wi} = freq struct  (powspctrm: [n_chan x n_freq])
% ================================================================
pow_win = cell(1, n_win);

for wi = 1:n_win
    t_start = win_def{wi, 1}(1);
    t_end   = win_def{wi, 1}(2);

    cfg_sel         = [];
    cfg_sel.latency = [t_start, t_end];
    data_win        = ft_selectdata(cfg_sel, data_all);

    cfg_f            = [];
    cfg_f.method     = 'mtmfft';
    cfg_f.taper      = 'boxcar';
    cfg_f.output     = 'pow';      % muV^2/Hz
    cfg_f.keeptrials = 'no';
    cfg_f.foilim     = foi_range;
    pow_win{wi}      = ft_freqanalysis(cfg_f, data_win);

    fprintf('Window %s: df = %.3f Hz,  n_freq = %d\n', ...
            win_def{wi, 2}, ...
            pow_win{wi}.freq(2) - pow_win{wi}.freq(1), ...
            length(pow_win{wi}.freq));
end

chan_labels = pow_win{1}.label;
n_chan      = length(chan_labels);
fprintf('\nRendering %d figures...\n', n_chan);

% ================================================================
% Plot one figure per channel
% ================================================================
for chi = 1:n_chan
    ch_name = chan_labels{chi};

    fig = figure('Units', 'centimeters', 'Position', [2, 2, 14, 9], 'Visible', 'off');
    hold on;

    for wi = 1:n_win
        freq = pow_win{wi};
        pow  = freq.powspctrm(chi, :);
        col  = win_colors{wi};
        lbl  = win_def{wi, 2};
        plot(freq.freq, pow, '-', 'Color', col, 'LineWidth', 1.6, ...
             'DisplayName', lbl);
    end

    % Alpha band highlight
    yl = ylim;
    patch([7 13 13 7], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.6], ...
          'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    text(10, yl(2) * 0.92, '\alpha', ...
         'HorizontalAlignment', 'center', 'FontSize', 10);

    xlabel('Frequency (Hz)');
    ylabel('\muV^2/Hz');
    title(['Power spectrum window comparison — ', ch_name]);
    xlim(foi_range);
    legend('show', 'Location', 'northeast', 'FontSize', 8);
    grid on; box on;

    saveas(fig, fullfile(res_dir, ['power_wcomp_', ch_name, '.png']));
    close(fig);

    if mod(chi, 10) == 0
        fprintf('  %d / %d done\n', chi, n_chan);
    end
end

fprintf('Done. %d figures saved to:\n  %s\n', n_chan, res_dir);
