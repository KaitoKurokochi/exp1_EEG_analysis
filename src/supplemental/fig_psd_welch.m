% fig_psd_welch.m
% Grand-average power spectral density (PSD) per group using Hanning-windowed
% FFT averaged across trials (Welch-style estimate).
%
% Purpose: verify that EEG signal quality under VR headset is within the
% range reported for gel-based EEG in prior studies (e.g., Fronso et al.,
% 2019: alpha PSD ~ 2.25 µV²/Hz open-eyes, ~ 7.8 µV²/Hz closed-eyes).
%
% Method: ft_freqanalysis (method='mtmfft', taper='hanning', keeptrials='no')
%   - Each trial is windowed and FFT-ed; results are averaged across trials.
%   - Output unit: µV²/Hz  (assuming input data is in µV).
%   - Frequency resolution: 1 / epoch_length (s)
%
% Data source: result/erp_group_cond/   (Correct Go + Correct NoGo pooled)
% Output:      result/fig_psd_welch/

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'fig_psd_welch');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ---- Frequency range to display ----
foi_range = [1 40];   % Hz  (1-40 Hz covers delta through low-gamma)

% ---- Colors ----
col_exp = [0.85, 0.33, 0.10];   % red-orange
col_nov = [0.00, 0.45, 0.74];   % blue

% ================================================================
% Compute PSD per group (pool Go + NoGo correct trials)
% ================================================================
psd = struct();

for gi = 1:length(groups)
    grp = groups{gi};
    data_all = [];

    for ci = 1:length(conditions)
        fname = fullfile(data_dir, [grp, '_', conditions{ci}, '.mat']);
        fprintf('Loading %s_%s ... ', grp, conditions{ci});
        load(fname);  % loads 'data'
        fprintf('n = %d trials\n', length(data.trial));

        if isempty(data_all)
            data_all = data;
        else
            data_all = ft_appenddata([], data_all, data);
        end
    end

    fprintf('Computing PSD for %s (total %d trials)...\n', grp, length(data_all.trial));

    cfg             = [];
    cfg.method      = 'mtmfft';
    cfg.taper       = 'hanning';
    cfg.output      = 'pow';       % µV²/Hz
    cfg.keeptrials  = 'no';        % trial average
    cfg.foilim      = foi_range;
    freq            = ft_freqanalysis(cfg, data_all);

    psd.(grp) = freq;
    fprintf('  freq resolution: %.3f Hz\n', freq.freq(2) - freq.freq(1));
end

% ================================================================
% Channel-average PSD (mean over all channels, excluding EOG/M1/M2)
% ================================================================
exclude_chans = {'EOG', 'M1', 'M2'};

for gi = 1:length(groups)
    grp  = groups{gi};
    freq = psd.(grp);

    % Find channels to include
    inc = ~ismember(freq.label, exclude_chans);
    psd.(grp).pow_chanmean     = squeeze(mean(freq.powspctrm(inc, :), 1));  % [n_freq]
    psd.(grp).pow_chanmean_sem = squeeze(std(freq.powspctrm(inc, :), 0, 1)) ...
                                 / sqrt(sum(inc));
end

freq_axis = psd.(groups{1}).freq;

% ================================================================
% Plot 1: Grand-average PSD (channel mean), Exp vs Nov
% ================================================================
fig1 = figure('Units', 'centimeters', 'Position', [2, 2, 16, 10], 'Visible', 'off');
hold on;

for gi = 1:length(groups)
    grp = groups{gi};
    m   = psd.(grp).pow_chanmean;
    s   = psd.(grp).pow_chanmean_sem;

    if strcmp(grp, 'exp')
        col   = col_exp;
        lbl   = 'Experts';
    else
        col   = col_nov;
        lbl   = 'Novices';
    end

    fill([freq_axis, fliplr(freq_axis)], [m+s, fliplr(m-s)], ...
         col, 'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(freq_axis, m, '-', 'Color', col, 'LineWidth', 1.8, 'DisplayName', lbl);
end

% Highlight alpha band
yl = ylim;
patch([7 13 13 7], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.6], ...
      'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(10, yl(2)*0.95, '\alpha', 'HorizontalAlignment', 'center', 'FontSize', 11);

xlabel('Frequency (Hz)');
ylabel('PSD (\muV^2/Hz)');
title('Grand-average PSD — Experts vs Novices (all correct trials)');
legend('show', 'Location', 'northeast', 'FontSize', 9);
xlim(foi_range);
grid on; box on;

exportgraphics(fig1, fullfile(res_dir, 'psd_exp_vs_nov.pdf'), 'ContentType', 'vector');
saveas(fig1, fullfile(res_dir, 'psd_exp_vs_nov.png'));
close(fig1);

% ================================================================
% Plot 2: Per-channel PSD at key electrodes (Fz, Cz, Pz, Oz)
% ================================================================
key_chans = {'Fz', 'Cz', 'Pz', 'Oz'};

fig2 = figure('Units', 'centimeters', 'Position', [2, 2, 24, 16], 'Visible', 'off');

for k = 1:length(key_chans)
    ch_name = key_chans{k};
    subplot(2, 2, k);
    hold on;

    for gi = 1:length(groups)
        grp  = groups{gi};
        freq = psd.(grp);
        ch_i = find(strcmp(freq.label, ch_name), 1);
        if isempty(ch_i)
            warning('%s not found', ch_name); continue;
        end

        m   = freq.powspctrm(ch_i, :);
        col = [col_exp; col_nov];
        if strcmp(grp, 'exp')
            lbl = 'Experts'; c = col_exp;
        else
            lbl = 'Novices'; c = col_nov;
        end
        plot(freq_axis, m, '-', 'Color', c, 'LineWidth', 1.5, 'DisplayName', lbl);
    end

    % Alpha band highlight
    yl = ylim;
    patch([7 13 13 7], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.6], ...
          'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    xlabel('Frequency (Hz)');
    ylabel('\muV^2/Hz');
    title(ch_name);
    xlim(foi_range);
    legend('show', 'Location', 'northeast', 'FontSize', 8);
    grid on; box on;
end

sgtitle('PSD at key electrodes — Experts vs Novices');
exportgraphics(fig2, fullfile(res_dir, 'psd_key_channels.pdf'), 'ContentType', 'vector');
saveas(fig2, fullfile(res_dir, 'psd_key_channels.png'));
close(fig2);

% ================================================================
% Print alpha-band PSD values for comparison with Fronso et al. (2019)
% ================================================================
fprintf('\n=== Alpha band PSD (7-13 Hz) for comparison with Fronso et al. (2019) ===\n');
fprintf('  [Reference] Gel-based, open-eyes resting:   2.25 ± 1.0  µV²/Hz\n');
fprintf('  [Reference] Gel-based, closed-eyes resting: 7.8  ± 4.8  µV²/Hz\n\n');

alpha_mask = (freq_axis >= 7) & (freq_axis <= 13);

for gi = 1:length(groups)
    grp  = groups{gi};
    freq = psd.(grp);
    inc  = ~ismember(freq.label, exclude_chans);

    % Channel-averaged alpha PSD
    alpha_pow = mean(freq.powspctrm(inc, alpha_mask), 2);  % [n_chan x 1]
    fprintf('  %s: channel-mean alpha PSD = %.2f ± %.2f µV²/Hz\n', ...
            grp, mean(alpha_pow), std(alpha_pow));
end

fprintf('\nSaved figures to %s\n', res_dir);
