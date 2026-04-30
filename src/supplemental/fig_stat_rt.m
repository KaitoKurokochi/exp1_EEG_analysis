% fig_stat_rt.m  [supplemental]
% Boxchart of mean RT per group with individual data points.
% Requires stat_rt.m to have been run first.
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'stat_rt');
res_dir  = fullfile(prj_dir, 'result', 'fig_stat_rt');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(data_dir, 'stat.mat'));

col_exp = [0.00, 0.45, 0.74];
col_nov = [0.85, 0.33, 0.10];

rt_vals = [stat.exp.m_rt(:); stat.nov.m_rt(:)];
x_grp   = [ones(12, 1); 2*ones(12, 1)];

fig = figure('Visible', 'off', 'Units', 'centimeters', ...
    'Position', [0, 0, 8, 9]);
hold on;

bx = boxchart(x_grp, rt_vals);
bx.BoxFaceColor     = [0.70, 0.70, 0.70];
bx.WhiskerLineColor = [0.40, 0.40, 0.40];
bx.MarkerColor      = [0.40, 0.40, 0.40];
bx.BoxWidth         = 0.5;

rng(0);
jitter = 0.12;
x_exp = 1 + (rand(1, 12) - 0.5) * jitter;
x_nov = 2 + (rand(1, 12) - 0.5) * jitter;
scatter(x_exp, stat.exp.m_rt, 30, col_exp, 'filled', 'MarkerFaceAlpha', 0.7);
scatter(x_nov, stat.nov.m_rt, 30, col_nov, 'filled', 'MarkerFaceAlpha', 0.7);

yl    = ylim;
y_top = yl(2);
y_brk = y_top + range(yl) * 0.06;
y_txt = y_brk + range(yl) * 0.03;
if     stat.p < 0.001, sig_str = '***';
elseif stat.p < 0.01,  sig_str = '**';
elseif stat.p < 0.05,  sig_str = '*';
else,                  sig_str = sprintf('p = %.3f', stat.p);
end
line([1 2], [y_brk y_brk], 'Color', 'k', 'LineWidth', 1);
line([1 1], [y_top y_brk], 'Color', 'k', 'LineWidth', 1);
line([2 2], [y_top y_brk], 'Color', 'k', 'LineWidth', 1);
text(1.5, y_txt, sig_str, 'HorizontalAlignment', 'center', 'FontSize', 10);

ylabel('Reaction Time (s)', 'FontSize', 9);
xlim([0.5 2.5]);
ylim([yl(1), y_txt + range(yl) * 0.05]);
set(gca, 'FontSize', 9, 'TickDir', 'out', 'Box', 'off', ...
    'XTick', [1 2], 'XTickLabel', {'Experienced', 'Novice'});
grid on;

print(fig, '-dsvg', fullfile(res_dir, 'rt.svg'));
close(fig);
fprintf('Saved: rt.svg\n');
