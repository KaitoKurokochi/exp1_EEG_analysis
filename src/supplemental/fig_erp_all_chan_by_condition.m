% fig_erp_all_chan_by_condition.m
% ERP waveforms for ALL channels, Correct Go vs Correct NoGo,
% Novices (left) vs Experts (right).
% Saves one PNG per channel to result/fig_erp_all_chan_by_condition/.
%
% Task code mapping (from mytrialfun.m):
%   Correct Go   : trialinfo(:,1) in {1, 4}
%   Correct NoGo : trialinfo(:,1) in {2, 3}
%
% Data source: result/prepro3/
% Output:      result/fig_erp_all_chan_by_condition/

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'prepro3');
res_dir  = fullfile(prj_dir, 'result', 'fig_erp_all_chan_by_condition');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ---- Condition definitions ----
cond_codes  = {[1, 4], [2, 3]};
cond_labels = {'Correct Go', 'Correct NoGo'};
cond_colors = {[0.85, 0.33, 0.10], [0.00, 0.45, 0.74]};

% ---- Time window ----
t_start = 0.0;   % s
t_end   = 1.0;   % s

% ================================================================
% Step 1: resolve channel list and time axis from the first available file
% ================================================================
chan_labels = {};
time_axis   = [];
t_mask      = [];

for gi = 1:length(groups)
    for pi = 1:12
        for si = 1:5
            fname = fullfile(data_dir, [groups{gi}, num2str(pi), '-', num2str(si), '.mat']);
            if ~exist(fname, 'file'), continue; end
            load(fname);  % loads 'data'
            chan_labels = data.label;
            time_axis   = data.time{1};
            t_mask      = (time_axis >= t_start) & (time_axis <= t_end);
            break;
        end
        if ~isempty(chan_labels), break; end
    end
    if ~isempty(chan_labels), break; end
end

n_chan    = length(chan_labels);
n_t       = sum(t_mask);
time_plot = time_axis(t_mask) * 1000;  % ms

fprintf('Channels: %d,  Time points (0-1 s): %d\n', n_chan, n_t);

% ================================================================
% Step 2: accumulate sum and sum-of-squares per (group x condition)
%         across all trials — avoids storing all raw trials in memory
% ================================================================
n_g = length(groups);
n_c = length(cond_codes);

acc_sum  = cell(n_g, n_c);   % [n_chan x n_t], running sum
acc_sum2 = cell(n_g, n_c);   % [n_chan x n_t], running sum of squares
acc_n    = zeros(n_g, n_c);  % trial count

for gi = 1:n_g
    for ci = 1:n_c
        acc_sum{gi, ci}  = zeros(n_chan, n_t);
        acc_sum2{gi, ci} = zeros(n_chan, n_t);
    end
end

for gi = 1:n_g
    for pi = 1:12
        for si = 1:5
            seg_id = [groups{gi}, num2str(pi), '-', num2str(si)];
            fname  = fullfile(data_dir, [seg_id, '.mat']);
            if ~exist(fname, 'file'), continue; end

            load(fname);  % loads 'data'
            task_codes = data.trialinfo(:, 1);

            for ci = 1:n_c
                trl_idx = find(ismember(task_codes, cond_codes{ci}));
                for ti = 1:length(trl_idx)
                    sig = data.trial{trl_idx(ti)}(:, t_mask);  % [n_chan x n_t]
                    acc_sum{gi, ci}  = acc_sum{gi, ci}  + sig;
                    acc_sum2{gi, ci} = acc_sum2{gi, ci} + sig .^ 2;
                    acc_n(gi, ci)    = acc_n(gi, ci) + 1;
                end
            end
        end
    end
    fprintf('Loaded group: %s\n', groups{gi});
end

% ================================================================
% Step 3: compute grand average and SEM
% ================================================================
gp_mean = cell(n_g, n_c);
gp_sem  = cell(n_g, n_c);

fprintf('\n=== Trial counts ===\n');
for gi = 1:n_g
    for ci = 1:n_c
        n = acc_n(gi, ci);
        fprintf('  %-4s  %-20s  n = %d\n', groups{gi}, cond_labels{ci}, n);
        if n == 0
            gp_mean{gi,ci} = zeros(n_chan, n_t);
            gp_sem{gi,ci}  = zeros(n_chan, n_t);
            continue;
        end
        m              = acc_sum{gi, ci} / n;
        v              = acc_sum2{gi, ci} / n - m .^ 2;
        v(v < 0)       = 0;  % numerical clamp
        gp_mean{gi,ci} = m;
        gp_sem{gi,ci}  = sqrt(v) / sqrt(n);
    end
end

% ================================================================
% Step 4: one figure per channel
% ================================================================
nov_gi = find(strcmp(groups, 'nov'));
exp_gi = find(strcmp(groups, 'exp'));
panel_order  = [nov_gi, exp_gi];
panel_titles = {'Novices', 'Experienced'};

fprintf('\nRendering %d figures...\n', n_chan);

for chi = 1:n_chan
    ch_name = chan_labels{chi};

    fig = figure('Units', 'centimeters', 'Position', [2, 2, 24, 10], 'Visible', 'off');

    % Compute shared y-limits across both groups and all conditions
    y_all = [];
    for gi_tmp = 1:n_g
        for ci = 1:n_c
            m = gp_mean{gi_tmp, ci}(chi, :);
            s = gp_sem{gi_tmp,  ci}(chi, :);
            y_all = [y_all, m + s, m - s]; %#ok<AGROW>
        end
    end
    y_pad  = (max(y_all) - min(y_all)) * 0.08;
    y_lim  = [min(y_all) - y_pad, max(y_all) + y_pad];

    for pi = 1:2
        gi = panel_order(pi);
        subplot(1, 2, pi);
        hold on;

        for ci = 1:n_c
            m   = gp_mean{gi, ci}(chi, :);
            s   = gp_sem{gi,  ci}(chi, :);
            col = cond_colors{ci};

            % SEM shading
            fill([time_plot, fliplr(time_plot)], ...
                 [m + s,      fliplr(m - s)],   ...
                 col, 'FaceAlpha', 0.18, 'EdgeColor', 'none', ...
                 'HandleVisibility', 'off');

            % Mean line
            plot(time_plot, m, '-', 'Color', col, 'LineWidth', 1.5, ...
                 'DisplayName', cond_labels{ci});
        end

        yline(0, 'k-',  'LineWidth', 0.6, 'HandleVisibility', 'off');
        xline(0, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');

        xlabel('Time (ms)');
        ylabel('\muV');
        title(panel_titles{pi});
        xlim([t_start*1000, t_end*1000]);
        ylim(y_lim);
        legend('show', 'Location', 'best', 'FontSize', 8);
        grid on; box on;
    end

    sgtitle(['ERP at ', ch_name, ' — Correct Go / Correct NoGo']);

    saveas(fig, fullfile(res_dir, ['erp_', ch_name, '.png']));
    close(fig);

    if mod(chi, 10) == 0
        fprintf('  %d / %d done\n', chi, n_chan);
    end
end

fprintf('Done. %d figures saved to:\n  %s\n', n_chan, res_dir);
