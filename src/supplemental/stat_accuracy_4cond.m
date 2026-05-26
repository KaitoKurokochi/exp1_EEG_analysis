%% stat_accuracy_4cond.m  [supplemental]
% 2-way mixed ANOVA for accuracy across 4 trial conditions
%   Between:    Group (exp / nov)
%   Within:     TrialType (4 levels: FF, SS, FS, SF)
%     FF = ff (Go,   fastball-fastball)
%     SS = cc (Go,   slider-slider)
%     FS = fc (NoGo, fastball-slider)
%     SF = cf (NoGo, slider-fastball)
%
% Post-hoc focus:
%   Go-pair    : FF vs SS  (within-Go pitch comparison)
%   NoGo-pair  : FS vs SF  (within-NoGo pitch comparison)
%
% Output: result/stat_accuracy_4cond/stat.mat and stat_result.txt

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'trialinfo');
res_dir  = fullfile(prj_dir, 'result', 'stat_accuracy_4cond');
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

% -------------------------------------------------------------------------
% load data
% -------------------------------------------------------------------------
load(fullfile(data_dir, 'exp.mat'));   % -> exp
load(fullfile(data_dir, 'nov.mat'));   % -> nov

% -------------------------------------------------------------------------
% collect 4-cell accuracy per participant
%   columns: [FF, SS, FS, SF]
%   FF = ff  (task==+1 / -1)
%   SS = cc  (task==+4 / -4)
%   FS = fc  (task==+2 / -2)
%   SF = cf  (task==+3 / -3)
% -------------------------------------------------------------------------
n_subj = 12;

exp.acc4 = zeros(n_subj, 4);
nov.acc4 = zeros(n_subj, 4);

for pi = 1:n_subj
    t = exp.trialinfo{1, pi}(:, 1);
    exp.acc4(pi, 1) = nnz(t == 1) / nnz(abs(t) == 1);   % FF
    exp.acc4(pi, 2) = nnz(t == 4) / nnz(abs(t) == 4);   % SS
    exp.acc4(pi, 3) = nnz(t == 2) / nnz(abs(t) == 2);   % FS
    exp.acc4(pi, 4) = nnz(t == 3) / nnz(abs(t) == 3);   % SF
end

for pi = 1:n_subj
    t = nov.trialinfo{1, pi}(:, 1);
    nov.acc4(pi, 1) = nnz(t == 1) / nnz(abs(t) == 1);
    nov.acc4(pi, 2) = nnz(t == 4) / nnz(abs(t) == 4);
    nov.acc4(pi, 3) = nnz(t == 2) / nnz(abs(t) == 2);
    nov.acc4(pi, 4) = nnz(t == 3) / nnz(abs(t) == 3);
end

% save intermediate
save(fullfile(res_dir, 'exp.mat'), 'exp', '-v7.3');
save(fullfile(res_dir, 'nov.mat'), 'nov', '-v7.3');

% -------------------------------------------------------------------------
% descriptive statistics
% -------------------------------------------------------------------------
cell_labels = {'FF', 'SS', 'FS', 'SF'};
all_acc = [exp.acc4; nov.acc4];

desc.M_exp  = mean(exp.acc4, 1);
desc.SD_exp = std(exp.acc4, 0, 1);
desc.M_nov  = mean(nov.acc4, 1);
desc.SD_nov = std(nov.acc4, 0, 1);
desc.M_all  = mean(all_acc, 1);
desc.SD_all = std(all_acc, 0, 1);

% -------------------------------------------------------------------------
% build table for fitrm
% -------------------------------------------------------------------------
var_names = {'group', 'FF', 'SS', 'FS', 'SF'};
var_types = {'categorical', 'double', 'double', 'double', 'double'};

tbl = table('Size', [0, length(var_names)], ...
            'VariableTypes', var_types, ...
            'VariableNames', var_names);

for pi = 1:n_subj
    tbl(end+1, :) = {categorical({'exp'}), ...
                     exp.acc4(pi,1), exp.acc4(pi,2), ...
                     exp.acc4(pi,3), exp.acc4(pi,4)};
end
for pi = 1:n_subj
    tbl(end+1, :) = {categorical({'nov'}), ...
                     nov.acc4(pi,1), nov.acc4(pi,2), ...
                     nov.acc4(pi,3), nov.acc4(pi,4)};
end

% -------------------------------------------------------------------------
% 2-way mixed ANOVA: TrialType(4) x Group
% -------------------------------------------------------------------------
within_design = table( ...
    categorical({'FF'; 'SS'; 'FS'; 'SF'}), ...
    'VariableNames', {'TrialType'});

rm = fitrm(tbl, 'FF-SF ~ group', 'WithinDesign', within_design);
stat.ranovatbl = ranova(rm, 'WithinModel', 'TrialType');

% -------------------------------------------------------------------------
% planned post-hoc comparisons (paired t-test, pooled across groups)
%   Go-pair  : FF vs SS
%   NoGo-pair: FS vs SF
%   Bonferroni: alpha = 0.05/2 = 0.025
% -------------------------------------------------------------------------
all_FF = [exp.acc4(:,1); nov.acc4(:,1)];
all_SS = [exp.acc4(:,2); nov.acc4(:,2)];
all_FS = [exp.acc4(:,3); nov.acc4(:,3)];
all_SF = [exp.acc4(:,4); nov.acc4(:,4)];

[stat.post_Go.h,   stat.post_Go.p,   stat.post_Go.ci,   stat.post_Go.stats]   = ...
    ttest(all_FF, all_SS, 'Alpha', 0.025);
[stat.post_NoGo.h, stat.post_NoGo.p, stat.post_NoGo.ci, stat.post_NoGo.stats] = ...
    ttest(all_FS, all_SF, 'Alpha', 0.025);

% per-group planned comparisons (Bonferroni alpha=0.0125, 4 tests)
[stat.post_exp_Go.h,   stat.post_exp_Go.p,   stat.post_exp_Go.ci,   stat.post_exp_Go.stats]   = ...
    ttest(exp.acc4(:,1), exp.acc4(:,2), 'Alpha', 0.0125);
[stat.post_exp_NoGo.h, stat.post_exp_NoGo.p, stat.post_exp_NoGo.ci, stat.post_exp_NoGo.stats] = ...
    ttest(exp.acc4(:,3), exp.acc4(:,4), 'Alpha', 0.0125);
[stat.post_nov_Go.h,   stat.post_nov_Go.p,   stat.post_nov_Go.ci,   stat.post_nov_Go.stats]   = ...
    ttest(nov.acc4(:,1), nov.acc4(:,2), 'Alpha', 0.0125);
[stat.post_nov_NoGo.h, stat.post_nov_NoGo.p, stat.post_nov_NoGo.ci, stat.post_nov_NoGo.stats] = ...
    ttest(nov.acc4(:,3), nov.acc4(:,4), 'Alpha', 0.0125);

% -------------------------------------------------------------------------
% save mat
% -------------------------------------------------------------------------
stat.tbl         = tbl;
stat.desc        = desc;
stat.cell_labels = cell_labels;
save(fullfile(res_dir, 'stat.mat'), 'stat', '-v7.3');

% -------------------------------------------------------------------------
% write txt report
% -------------------------------------------------------------------------
fid = fopen(fullfile(res_dir, 'stat_result.txt'), 'w');

fprintf(fid, '=== 2-way mixed ANOVA: Accuracy across 4 trial conditions ===\n');
fprintf(fid, 'Between: Group (exp / nov, n=12 each)\n');
fprintf(fid, 'Within:  TrialType (FF / SS / FS / SF)\n\n');

fprintf(fid, '--- Descriptive statistics (M +/- SD) ---\n');
fprintf(fid, '%-6s  %s\n', '', strjoin(cell_labels, '             '));
fprintf(fid, '%-6s', 'Exp');
for ci = 1:4
    fprintf(fid, '  %.4f(%.4f)', desc.M_exp(ci), desc.SD_exp(ci));
end
fprintf(fid, '\n');
fprintf(fid, '%-6s', 'Nov');
for ci = 1:4
    fprintf(fid, '  %.4f(%.4f)', desc.M_nov(ci), desc.SD_nov(ci));
end
fprintf(fid, '\n');
fprintf(fid, '%-6s', 'All');
for ci = 1:4
    fprintf(fid, '  %.4f(%.4f)', desc.M_all(ci), desc.SD_all(ci));
end
fprintf(fid, '\n\n');

fprintf(fid, '--- ranova table ---\n');
fprintf(fid, '%s\n\n', formattable(stat.ranovatbl));

fprintf(fid, '--- Planned comparisons [pooled across groups] (Bonferroni alpha=0.025) ---\n');
fprintf(fid, 'Go-pair   (FF vs SS): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.post_Go.stats.df,   stat.post_Go.stats.tstat,   stat.post_Go.p,   stat.post_Go.h);
fprintf(fid, 'NoGo-pair (FS vs SF): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.post_NoGo.stats.df, stat.post_NoGo.stats.tstat, stat.post_NoGo.p, stat.post_NoGo.h);

fprintf(fid, '\n--- Per-group planned comparisons (Bonferroni alpha=0.0125, 4 tests) ---\n');
fprintf(fid, 'Exp  Go   (FF vs SS): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.post_exp_Go.stats.df,   stat.post_exp_Go.stats.tstat,   stat.post_exp_Go.p,   stat.post_exp_Go.h);
fprintf(fid, 'Exp  NoGo (FS vs SF): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.post_exp_NoGo.stats.df, stat.post_exp_NoGo.stats.tstat, stat.post_exp_NoGo.p, stat.post_exp_NoGo.h);
fprintf(fid, 'Nov  Go   (FF vs SS): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.post_nov_Go.stats.df,   stat.post_nov_Go.stats.tstat,   stat.post_nov_Go.p,   stat.post_nov_Go.h);
fprintf(fid, 'Nov  NoGo (FS vs SF): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.post_nov_NoGo.stats.df, stat.post_nov_NoGo.stats.tstat, stat.post_nov_NoGo.p, stat.post_nov_NoGo.h);

fclose(fid);

% -------------------------------------------------------------------------
% console summary
% -------------------------------------------------------------------------
disp('=== 2-way mixed ANOVA: Accuracy across 4 trial conditions ===');
disp(stat.ranovatbl);
fprintf('Planned Go   (FF vs SS): t(%d)=%.4f, p=%.4f\n', ...
    stat.post_Go.stats.df,   stat.post_Go.stats.tstat,   stat.post_Go.p);
fprintf('Planned NoGo (FS vs SF): t(%d)=%.4f, p=%.4f\n', ...
    stat.post_NoGo.stats.df, stat.post_NoGo.stats.tstat, stat.post_NoGo.p);
fprintf('Results saved to: %s\n', res_dir);

% =========================================================================
function s = formattable(T)
    s = evalc('disp(T)');
end
