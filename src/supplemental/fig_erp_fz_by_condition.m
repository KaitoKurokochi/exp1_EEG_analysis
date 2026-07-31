% fig_erp_fz_by_condition.m
% ERP waveform at Fz electrode separated by response condition.
% Analogous to Figure S3 in Muraskin et al. (2015):
%   Correct Go / Correct NoGo / Incorrect NoGo
%   for Novices (left panel) and Experts (right panel).
%
% Task code mapping (from mytrialfun.m):
%   Correct Go      : trialinfo(:,1) in {1, 4}
%   Correct NoGo    : trialinfo(:,1) in {2, 3}
%   Incorrect NoGo  : trialinfo(:,1) in {-2, -3}  (false alarm)
%   Incorrect Go    : trialinfo(:,1) in {-1, -4}  (miss, excluded)
%
% Data source: result/prepro3/
% Output:      result/fig_erp_fz_by_condition/

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'prepro3');
res_dir  = fullfile(prj_dir, 'result', 'fig_erp_fz_by_condition');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

% ---- Condition definitions ----
% cond_codes  = {[1, 4], [2, 3], [-2, -3], [-1, -4]};
% cond_labels = {'Correct Go', 'Correct NoGo', 'Incorrect NoGo', 'Incorrect Go'};
cond_codes  = {[1, 4], [2, 3]};
cond_labels = {'Correct Go', 'Correct NoGo'};
cond_colors = {[0.85, 0.33, 0.10], [0.00, 0.45, 0.74], [0.47, 0.67, 0.19], [0.63, 0.08, 0.18]};

% ---- Time window ----
t_start = 0.0;   % s
t_end   = 1.0;   % s

fz_name = 'Fz';

% ================================================================
% Collect single-trial Fz waveforms from prepro3
% ================================================================
% Storage: group x condition — cell of [n_trials x n_timepoints] matrices
all_data  = cell(length(groups), length(cond_codes));
time_axis = [];

for gi = 1:length(groups)
    for pi = 1:12
        for si = 1:5
            seg_id = [groups{gi}, num2str(pi), '-', num2str(si)];
            fname  = fullfile(data_dir, [seg_id, '.mat']);
            if ~exist(fname, 'file'), continue; end

            load(fname);  % loads 'data'

            % Resolve Fz channel index
            fz_idx = find(strcmp(data.label, fz_name), 1);
            if isempty(fz_idx)
                warning('%s: Fz not found, skipping', seg_id);
                continue;
            end

            % Resolve time axis and mask (once)
            if isempty(time_axis)
                time_axis = data.time{1};
                t_mask    = (time_axis >= t_start) & (time_axis <= t_end);
            end

            task_codes = data.trialinfo(:, 1);

            for ci = 1:length(cond_codes)
                trl_idx = find(ismember(task_codes, cond_codes{ci}));
                if isempty(trl_idx), continue; end

                for ti = 1:length(trl_idx)
                    sig = data.trial{trl_idx(ti)}(fz_idx, t_mask);  % 1 x n_t
                    all_data{gi, ci} = [all_data{gi, ci}; sig];
                end
            end
        end
    end
end

time_plot = time_axis(t_mask) * 1000;  % convert to ms

% ================================================================
% Grand average and SEM (across all pooled trials)
% ================================================================
gp_mean = cell(length(groups), length(cond_codes));
gp_sem  = cell(length(groups), length(cond_codes));

fprintf('\n=== Trial counts ===\n');
for gi = 1:length(groups)
    for ci = 1:length(cond_codes)
        mat = all_data{gi, ci};   % [n_trials x n_t]
        if isempty(mat)
            gp_mean{gi,ci} = zeros(1, sum(t_mask));
            gp_sem{gi,ci}  = zeros(1, sum(t_mask));
            fprintf('  %-4s  %-20s  n = 0\n', groups{gi}, cond_labels{ci});
            continue;
        end
        n = size(mat, 1);
        gp_mean{gi,ci} = mean(mat, 1);
        gp_sem{gi,ci}  = std(mat, 0, 1) / sqrt(n);
        fprintf('  %-4s  %-20s  n = %d trials\n', groups{gi}, cond_labels{ci}, n);
    end
end

% ================================================================
% Plot (2 panels: Novices | Experts, matching Muraskin Fig S3)
% ================================================================
% config.m sets groups = {'nov', 'exp'}; map to panel order
nov_gi = find(strcmp(groups, 'nov'));
exp_gi = find(strcmp(groups, 'exp'));
panel_order  = [nov_gi, exp_gi];
panel_titles = {'Novices', 'Experienced'};

fig = figure('Units', 'centimeters', 'Position', [2, 2, 24, 10], 'Visible', 'off');

fprintf('\n=== Amplitude ranges (grand average, 0-1000 ms, Fz) ===\n');
for pi = 1:2
    gi  = panel_order(pi);
    ax  = subplot(1, 2, pi);   %#ok<LAXES>
    hold on;

    for ci = 1:length(cond_codes)
        m   = gp_mean{gi, ci};
        s   = gp_sem{gi, ci};
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

    % Reference lines
    yline(0, 'k-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
    xline(0, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');

    xlabel('Time (ms)');
    ylabel('\muV');
    title(panel_titles{pi});
    xlim([t_start * 1000, t_end * 1000]);
    legend('show', 'Location', 'best', 'FontSize', 8);
    grid on; box on;

    % Report amplitude range
    all_m = cell2mat(gp_mean(gi, :));
    fprintf('  %-8s  min = %.3f µV,  max = %.3f µV,  range = %.3f µV\n', ...
            groups{gi}, min(all_m(:)), max(all_m(:)), max(all_m(:)) - min(all_m(:)));
end

sgtitle('ERP at Fz — Correct Go / Correct NoGo / Incorrect NoGo');

% ---- Save ----
exportgraphics(fig, fullfile(res_dir, 'erp_fz_by_condition.pdf'), 'ContentType', 'vector');
saveas(fig, fullfile(res_dir, 'erp_fz_by_condition.png'));
fprintf('\nSaved to %s\n', res_dir);
close(fig);
