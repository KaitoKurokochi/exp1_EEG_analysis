
% fig_power_cond_chanmean.m
% Grand-average power spectrum (channel mean, all electrodes) for
% Correct Go vs Correct NoGo, shown separately for Novices and Experts.
%
% Method: ft_freqanalysis (method='mtmfft', taper='boxcar', keeptrials='no')
%   Window: 0 to +1000 ms (1.0 s), delta_f = 1.0 Hz.
%   All channels averaged after computing per-channel power spectrum.
%   Output unit: muV^2/Hz.
%
% Data source: result/erp_group_cond/
% Output:      result/fig_power_cond_chanmean/

clear;
config;

% ================================================================
% Settings
% ================================================================
foi_range  = [1 40];           % Hz
t_win      = [0.00, 1.00];     % s  (1.0 s window -> df = 1.0 Hz)

% Channels to exclude from the grand mean
exclude_chans = {'EOG', 'M1', 'M2'};

% Condition appearance
cond_labels = {'Correct Go', 'Correct NoGo'};
cond_colors = {[0.85, 0.33, 0.10], [0.00, 0.45, 0.74]};

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'fig_power_cond_chanmean');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ================================================================
% Compute channel-mean power spectrum per group x condition
%   pow_gc{gi, ci}.chanmean : [1 x n_freq]  (mean over included channels)
% ================================================================
n_g  = length(groups);
n_c  = length(conditions);
pow_gc = cell(n_g, n_c);

for gi = 1:n_g
    grp = groups{gi};

    for ci = 1:n_c
        fname = fullfile(data_dir, [grp, '_', conditions{ci}, '.mat']);
        fprintf('Loading %s_%s ... ', grp, conditions{ci});
        load(fname);  % loads 'data'
        fprintf('%d trials\n', length(data.trial));

        % Select time window
        cfg_sel         = [];
        cfg_sel.latency = t_win;
        data_win        = ft_selectdata(cfg_sel, data);

        % Power spectrum (all channels, trial-averaged)
        cfg_f            = [];
        cfg_f.method     = 'mtmfft';
        cfg_f.taper      = 'boxcar';
        cfg_f.output     = 'pow';      % muV^2/Hz
        cfg_f.keeptrials = 'no';
        cfg_f.foilim     = foi_range;
        freq             = ft_freqanalysis(cfg_f, data_win);

        % Channel mean (exclude EOG/reference channels)
        inc = ~ismember(freq.label, exclude_chans);
        freq.chanmean = mean(freq.powspctrm(inc, :), 1);  % [1 x n_freq]

        pow_gc{gi, ci} = freq;
        fprintf('  df = %.3f Hz,  included channels = %d\n', ...
                freq.freq(2) - freq.freq(1), sum(inc));
    end
end

freq_axis = pow_gc{1, 1}.freq;

% ================================================================
% Plot: [Novices | Experts] x [Go / NoGo]
% ================================================================
nov_gi = find(strcmp(groups, 'nov'));
exp_gi = find(strcmp(groups, 'exp'));
panel_order  = [nov_gi, exp_gi];
panel_titles = {'Novices', 'Experts'};

fig = figure('Units', 'centimeters', 'Position', [2, 2, 22, 9], 'Visible', 'off');

for pi = 1:2
    gi = panel_order(pi);
    subplot(1, 2, pi);
    hold on;

    for ci = 1:n_c
        pow = pow_gc{gi, ci}.chanmean;
        col = cond_colors{ci};
        lbl = cond_labels{ci};
        plot(freq_axis, pow, '-', 'Color', col, 'LineWidth', 1.8, ...
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
    title(panel_titles{pi});
    xlim(foi_range);
    legend('show', 'Location', 'northeast', 'FontSize', 9);
    grid on; box on;
end

sgtitle(sprintf('Power spectrum — channel mean, all electrodes (window: %.1f–%.1f s, df=%.1f Hz)', ...
        t_win(1), t_win(2), freq_axis(2) - freq_axis(1)));

out_base = fullfile(res_dir, 'power_cond_chanmean');
saveas(fig, [out_base, '.png']);
exportgraphics(fig, [out_base, '.pdf'], 'ContentType', 'vector');
close(fig);

fprintf('\nDone. Figure saved to:\n  %s\n', res_dir);
