% fig_stat_accuracy.m  [supplemental]
% Boxchart of accuracy per condition x group.
% Requires stat_accuracy.m to have been run first.
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'stat_accuracy');
res_dir  = fullfile(prj_dir, 'result', 'fig_stat_accuracy');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

load(fullfile(data_dir, 'stat.mat'));

col_exp = [0.00, 0.45, 0.74];
col_nov = [0.85, 0.33, 0.10];

plot_tbl = stack(stat.tbl, {'go_accuracy', 'nogo_accuracy'}, ...
    'NewDataVariableName', 'accuracy', ...
    'IndexVariableName', 'condition');
plot_tbl.condition = renamecats(categorical(plot_tbl.condition), ...
    {'go_accuracy', 'nogo_accuracy'}, {'Go', 'No-Go'});

fig = figure('Visible', 'off', 'Units', 'centimeters', ...
    'Position', [0, 0, 10, 9]);

bx = boxchart(plot_tbl.condition, plot_tbl.accuracy, 'GroupByColor', plot_tbl.group);
for k = 1:numel(bx)
    if strcmp(char(bx(k).DisplayName), 'exp')
        bx(k).BoxFaceColor     = col_exp;
        bx(k).WhiskerLineColor = col_exp;
        bx(k).MarkerColor      = col_exp;
        bx(k).DisplayName      = 'Experienced';
    else
        bx(k).BoxFaceColor     = col_nov;
        bx(k).WhiskerLineColor = col_nov;
        bx(k).MarkerColor      = col_nov;
        bx(k).DisplayName      = 'Novice';
    end
end

% Condition main effect bracket (2-way repeated-measures ANOVA)
% interaction n.s. → no per-condition group markers; only Condition main effect shown
hold on;
p_cond = stat.ranovatbl{'(Intercept):Condition', 'pValue'};
if     p_cond < 0.001, sig_cond = '***';
elseif p_cond < 0.01,  sig_cond = '**';
elseif p_cond < 0.05,  sig_cond = '*';
else,                  sig_cond = 'n.s.';
end
ylim([0, 1.15]);
y_bar = 1.07;  y_tic = 1.04;  y_txt = 1.10;
line([1 2], [y_bar y_bar], 'Color', 'k', 'LineWidth', 1);
line([1 1], [y_tic  y_bar], 'Color', 'k', 'LineWidth', 1);
line([2 2], [y_tic  y_bar], 'Color', 'k', 'LineWidth', 1);
text(1.5, y_txt, sig_cond, 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');

legend('Location', 'southeast', 'FontSize', 8);
ylabel('Accuracy', 'FontSize', 9);
xlabel('Condition', 'FontSize', 9);
set(gca, 'FontSize', 9, 'TickDir', 'out', 'Box', 'off');
grid on;

print(fig, '-dsvg', fullfile(res_dir, 'accuracy.svg'));
close(fig);
fprintf('Saved: accuracy.svg\n');
