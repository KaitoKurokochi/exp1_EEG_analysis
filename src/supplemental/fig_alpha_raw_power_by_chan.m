% fig_alpha_raw_power_by_chan.m
% Time course of raw (pre-baseline-correction) alpha power (µV²) per channel.
% Conditions: Correct Go vs Correct NoGo, Novices (left) vs Experts (right).
% Saves one PNG per channel to result/fig_alpha_raw_power_by_chan/.
%
% Wavelet parameters are identical to erp_to_freq_alpha.m:
%   foi   = logspace(log10(7), log10(13), 5)
%   width = 3 * (foi/3).^(log(12/3)/log(40/3))   [Minami & Amano, 2017]
%   toi   = full epoch at 50 ms steps
%
% Unlike erp_to_freq_alpha.m, ft_freqbaseline is NOT applied here.
% Power is summarized (median) over the 5 alpha frequency points (7-13 Hz).
% Units: µV²
%
% Data source: result/erp_group_cond/   (Correct Go / Correct NoGo only)
% Output:      result/fig_alpha_raw_power_by_chan/

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'fig_alpha_raw_power_by_chan');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ---- Conditions (erp_group_cond only has correct trials) ----
cond_labels = {'Correct Go', 'Correct NoGo'};
cond_colors = {[0.85, 0.33, 0.10], [0.00, 0.45, 0.74]};

% ---- Wavelet parameters (same as erp_to_freq_alpha.m) ----
foi   = logspace(log10(7), log10(13), 5);
width = 3 * (foi / 3) .^ (log(12/3) / log(40/3));

% ---- Time window for display ----
% Reliable range limited by wavelet edge effect at lowest alpha freq (7 Hz):
%   half-window = 4.72 cycles / (2 * 7 Hz) ≈ 337 ms
%   epoch: -500 ms to +1000 ms → reliable: -163 ms to +663 ms
t_start = -0.1;  % s  (-100 ms)
t_end   =  0.65; % s  (+650 ms)

% ================================================================
% Compute trial-averaged raw alpha power per group x condition
% ================================================================
% Result: avg_pow{gi, ci} — struct from ft_freqanalysis (keeptrials='no')
%   .powspctrm : [n_chan x n_freq x n_time]

n_g = length(groups);
n_c = length(conditions);   % go / nogo  (matches erp_group_cond filenames)
avg_pow = cell(n_g, n_c);

fprintf('Running wavelet transform (no baseline correction)...\n');
for gi = 1:n_g
    for ci = 1:n_c
        fname = fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat']);
        fprintf('  loading: %s_%s ... ', groups{gi}, conditions{ci});
        load(fname);  % loads 'data'

        % Wavelet transform — no baseline correction
        cfg            = [];
        cfg.method     = 'wavelet';
        cfg.output     = 'pow';
        cfg.keeptrials = 'no';   % trial average directly
        cfg.foi        = foi;
        cfg.width      = width;
        cfg.toi        = round((data.time{1}(1) : 0.05 : data.time{1}(end)) ...
                               * data.fsample) / data.fsample;
        freq = ft_freqanalysis(cfg, data);

        avg_pow{gi, ci} = freq;
        fprintf('done  (n_trials = %d)\n', length(data.trial));
    end
end

% ================================================================
% Extract per-channel time courses: median over alpha frequencies
%   pow_tc{gi, ci} : [n_chan x n_time]  in µV²
% ================================================================
pow_tc    = cell(n_g, n_c);
time_freq = avg_pow{1,1}.time;          % full time axis from wavelet
t_mask    = (time_freq >= t_start) & (time_freq <= t_end);
time_plot = time_freq(t_mask) * 1000;   % ms

for gi = 1:n_g
    for ci = 1:n_c
        % powspctrm: [n_chan x n_freq x n_time]
        % median over n_freq (alpha, 5 points)
        pow_tc{gi, ci} = squeeze(median(avg_pow{gi, ci}.powspctrm(:, :, t_mask), 2));
        % result: [n_chan x n_t]
    end
end

chan_labels = avg_pow{1,1}.label;
n_chan      = length(chan_labels);

fprintf('\nChannels: %d,  Time points (0-1 s): %d\n', n_chan, sum(t_mask));

% ================================================================
% Plot one figure per channel
% ================================================================
nov_gi = find(strcmp(groups, 'nov'));
exp_gi = find(strcmp(groups, 'exp'));
panel_order  = [nov_gi, exp_gi];
panel_titles = {'Novices', 'Experienced'};

% Map conditions order: conditions = {'go','nogo'} from config.m
go_ci   = find(strcmp(conditions, 'go'));
nogo_ci = find(strcmp(conditions, 'nogo'));
plot_ci_order = [go_ci, nogo_ci];  % Correct Go first, then Correct NoGo

fprintf('Rendering %d figures...\n', n_chan);

for chi = 1:n_chan
    ch_name = chan_labels{chi};

    % Shared y-limits across both groups
    y_all = [];
    for gi_tmp = 1:n_g
        for ci = 1:n_c
            y_all = [y_all, pow_tc{gi_tmp, ci}(chi, :)]; %#ok<AGROW>
        end
    end
    y_pad = (max(y_all) - min(y_all)) * 0.08;
    if y_pad == 0, y_pad = 0.01; end
    y_lim = [min(y_all) - y_pad, max(y_all) + y_pad];

    fig = figure('Units', 'centimeters', 'Position', [2, 2, 24, 10], 'Visible', 'off');

    for pi = 1:2
        gi = panel_order(pi);
        subplot(1, 2, pi);
        hold on;

        for k = 1:length(plot_ci_order)
            ci  = plot_ci_order(k);
            col = cond_colors{k};
            m   = pow_tc{gi, ci}(chi, :);

            plot(time_plot, m, '-', 'Color', col, 'LineWidth', 1.5, ...
                 'DisplayName', cond_labels{k});
        end

        xline(0, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');

        xlabel('Time (ms)');
        ylabel('\muV^2');
        title(panel_titles{pi});
        xlim([t_start*1000, t_end*1000]);
        ylim(y_lim);
        legend('show', 'Location', 'best', 'FontSize', 8);
        grid on; box on;
    end

    sgtitle(['Alpha power (raw, \muV^2) at ', ch_name, ...
             ' — Correct Go / Correct NoGo']);

    saveas(fig, fullfile(res_dir, ['alpha_raw_', ch_name, '.png']));
    close(fig);

    if mod(chi, 10) == 0
        fprintf('  %d / %d done\n', chi, n_chan);
    end
end

fprintf('Done. %d figures saved to:\n  %s\n', n_chan, res_dir);
