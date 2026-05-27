%% stat_accuracy_3way.m  [supplemental]
% 3-way mixed ANOVA for accuracy
%   Between:    Group (exp / nov)
%   Within-1:   GoNoGo (Go={ff,cc}, NoGo={fc,cf})
%   Within-2:   Pitch (first-pitch Fastball={ff,fc} vs Slider={cc,cf})
%
% task column coding in trialinfo{pi}(:,1):
%   +1=ff correct, -1=ff incorrect  (Go-F)
%   +2=fc correct, -2=fc incorrect  (NoGo-F)
%   +3=cf correct, -3=cf incorrect  (NoGo-S)
%   +4=cc correct, -4=cc incorrect  (Go-S)
%
% Output: result/stat_accuracy_3way/stat.mat and stat_result.txt

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'trialinfo');   % raw trialinfo
res_dir  = fullfile(prj_dir, 'result', 'stat_accuracy_3way');
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
%   columns: [GoF, GoS, NoGoF, NoGoS]
%   GoF   = ff  (task==+1 or -1)
%   GoS   = cc  (task==+4 or -4)
%   NoGoF = fc  (task==+2 or -2)
%   NoGoS = cf  (task==+3 or -3)
% -------------------------------------------------------------------------
n_subj = 12;

exp.acc4 = zeros(n_subj, 4);   % [GoF, GoS, NoGoF, NoGoS]
nov.acc4 = zeros(n_subj, 4);

for pi = 1:n_subj
    t_exp = exp.trialinfo{1, pi}(:, 1);
    exp.acc4(pi, 1) = nnz(t_exp ==  1) / nnz(abs(t_exp) == 1);   % GoF
    exp.acc4(pi, 2) = nnz(t_exp ==  4) / nnz(abs(t_exp) == 4);   % GoS
    exp.acc4(pi, 3) = nnz(t_exp ==  2) / nnz(abs(t_exp) == 2);   % NoGoF
    exp.acc4(pi, 4) = nnz(t_exp ==  3) / nnz(abs(t_exp) == 3);   % NoGoS
end

for pi = 1:n_subj
    t_nov = nov.trialinfo{1, pi}(:, 1);
    nov.acc4(pi, 1) = nnz(t_nov ==  1) / nnz(abs(t_nov) == 1);   % GoF
    nov.acc4(pi, 2) = nnz(t_nov ==  4) / nnz(abs(t_nov) == 4);   % GoS
    nov.acc4(pi, 3) = nnz(t_nov ==  2) / nnz(abs(t_nov) == 2);   % NoGoF
    nov.acc4(pi, 4) = nnz(t_nov ==  3) / nnz(abs(t_nov) == 3);   % NoGoS
end

% save intermediate data
save(fullfile(res_dir, 'exp.mat'), 'exp', '-v7.3');
save(fullfile(res_dir, 'nov.mat'), 'nov', '-v7.3');

% -------------------------------------------------------------------------
% descriptive statistics  [M, SD]  per cell
% -------------------------------------------------------------------------
cell_labels = {'GoF', 'GoS', 'NoGoF', 'NoGoS'};
all_acc = [exp.acc4; nov.acc4];   % 24 x 4

desc.M_exp  = mean(exp.acc4, 1);
desc.SD_exp = std(exp.acc4, 0, 1);
desc.M_nov  = mean(nov.acc4, 1);
desc.SD_nov = std(nov.acc4, 0, 1);
desc.M_all  = mean(all_acc, 1);
desc.SD_all = std(all_acc, 0, 1);

% -------------------------------------------------------------------------
% build table for fitrm
%   rows = 24 participants
%   columns: group (categorical), GoF, GoS, NoGoF, NoGoS
% -------------------------------------------------------------------------
var_names = {'group', 'GoF', 'GoS', 'NoGoF', 'NoGoS'};
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
% 3-way mixed ANOVA via fitrm + ranova
%   Within design: 2x2 (GoNoGo x Pitch)
%     factor GoNoGo: Go=[GoF,GoS]  vs  NoGo=[NoGoF,NoGoS]
%     factor Pitch:  F=[GoF,NoGoF] vs  S=[GoS,NoGoS]
% -------------------------------------------------------------------------
within_design = table( ...
    categorical({'Go';  'Go';  'NoGo'; 'NoGo'}), ...
    categorical({'F';   'S';   'F';    'S'}), ...
    'VariableNames', {'GoNoGo', 'Pitch'});

rm = fitrm(tbl, 'GoF-NoGoS ~ group', 'WithinDesign', within_design);
stat.ranovatbl = ranova(rm, 'WithinModel', 'GoNoGo*Pitch');

% -------------------------------------------------------------------------
% simple main effects of Pitch within each GoNoGo level
%   paired t-test: GoF vs GoS  and  NoGoF vs NoGoS
%   Bonferroni correction: alpha = 0.05/2 = 0.025
% -------------------------------------------------------------------------
all_GoF   = [exp.acc4(:,1); nov.acc4(:,1)];
all_GoS   = [exp.acc4(:,2); nov.acc4(:,2)];
all_NoGoF = [exp.acc4(:,3); nov.acc4(:,3)];
all_NoGoS = [exp.acc4(:,4); nov.acc4(:,4)];

[stat.sme_Go.h,   stat.sme_Go.p,   stat.sme_Go.ci,   stat.sme_Go.stats]   = ...
    ttest(all_GoF,   all_GoS,   'Alpha', 0.025);
[stat.sme_NoGo.h, stat.sme_NoGo.p, stat.sme_NoGo.ci, stat.sme_NoGo.stats] = ...
    ttest(all_NoGoF, all_NoGoS, 'Alpha', 0.025);

% -------------------------------------------------------------------------
% per-group simple main effects of Pitch within each GoNoGo level
%   paired t-test within each group separately
%   Bonferroni correction: alpha = 0.05/4 = 0.0125 (4 tests)
% -------------------------------------------------------------------------
[stat.sme_exp_Go.h,   stat.sme_exp_Go.p,   stat.sme_exp_Go.ci,   stat.sme_exp_Go.stats]   = ...
    ttest(exp.acc4(:,1), exp.acc4(:,2), 'Alpha', 0.0125);
[stat.sme_exp_NoGo.h, stat.sme_exp_NoGo.p, stat.sme_exp_NoGo.ci, stat.sme_exp_NoGo.stats] = ...
    ttest(exp.acc4(:,3), exp.acc4(:,4), 'Alpha', 0.0125);
[stat.sme_nov_Go.h,   stat.sme_nov_Go.p,   stat.sme_nov_Go.ci,   stat.sme_nov_Go.stats]   = ...
    ttest(nov.acc4(:,1), nov.acc4(:,2), 'Alpha', 0.0125);
[stat.sme_nov_NoGo.h, stat.sme_nov_NoGo.p, stat.sme_nov_NoGo.ci, stat.sme_nov_NoGo.stats] = ...
    ttest(nov.acc4(:,3), nov.acc4(:,4), 'Alpha', 0.0125);

% -------------------------------------------------------------------------
% save mat
% -------------------------------------------------------------------------
stat.tbl        = tbl;
stat.desc       = desc;
stat.cell_labels = cell_labels;
save(fullfile(res_dir, 'stat.mat'), 'stat', '-v7.3');

% -------------------------------------------------------------------------
% write txt report
% -------------------------------------------------------------------------
fid = fopen(fullfile(res_dir, 'stat_result.txt'), 'w');

fprintf(fid, '=== 3-way mixed ANOVA: Accuracy ===\n');
fprintf(fid, 'Between: Group (exp / nov, n=12 each)\n');
fprintf(fid, 'Within:  GoNoGo (Go / NoGo) x Pitch (F / S)\n\n');

fprintf(fid, '--- Descriptive statistics (M +/- SD) ---\n');
fprintf(fid, '%-8s  %s\n', '', strjoin(cell_labels, '      '));
fprintf(fid, '%-8s', 'Exp');
for ci = 1:4
    fprintf(fid, '  %.4f(%.4f)', desc.M_exp(ci), desc.SD_exp(ci));
end
fprintf(fid, '\n');
fprintf(fid, '%-8s', 'Nov');
for ci = 1:4
    fprintf(fid, '  %.4f(%.4f)', desc.M_nov(ci), desc.SD_nov(ci));
end
fprintf(fid, '\n');
fprintf(fid, '%-8s', 'All');
for ci = 1:4
    fprintf(fid, '  %.4f(%.4f)', desc.M_all(ci), desc.SD_all(ci));
end
fprintf(fid, '\n\n');

fprintf(fid, '--- ranova table ---\n');
fprintf(fid, '%s\n\n', formattable(stat.ranovatbl));

fprintf(fid, '--- Simple main effect of Pitch [pooled across groups] (Bonferroni alpha=0.025) ---\n');
fprintf(fid, 'Go   condition  (GoF vs GoS):    t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.sme_Go.stats.df,   stat.sme_Go.stats.tstat,   stat.sme_Go.p,   stat.sme_Go.h);
fprintf(fid, 'NoGo condition  (NoGoF vs NoGoS): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.sme_NoGo.stats.df, stat.sme_NoGo.stats.tstat, stat.sme_NoGo.p, stat.sme_NoGo.h);

fprintf(fid, '\n--- Per-group simple main effect of Pitch (Bonferroni alpha=0.0125, 4 tests) ---\n');
fprintf(fid, 'Exp  Go   (ff vs cc): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.sme_exp_Go.stats.df,   stat.sme_exp_Go.stats.tstat,   stat.sme_exp_Go.p,   stat.sme_exp_Go.h);
fprintf(fid, 'Exp  NoGo (fc vs cf): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.sme_exp_NoGo.stats.df, stat.sme_exp_NoGo.stats.tstat, stat.sme_exp_NoGo.p, stat.sme_exp_NoGo.h);
fprintf(fid, 'Nov  Go   (ff vs cc): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.sme_nov_Go.stats.df,   stat.sme_nov_Go.stats.tstat,   stat.sme_nov_Go.p,   stat.sme_nov_Go.h);
fprintf(fid, 'Nov  NoGo (fc vs cf): t(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.sme_nov_NoGo.stats.df, stat.sme_nov_NoGo.stats.tstat, stat.sme_nov_NoGo.p, stat.sme_nov_NoGo.h);

fclose(fid);

% -------------------------------------------------------------------------
% console summary
% -------------------------------------------------------------------------
disp('=== 3-way mixed ANOVA: Accuracy ===');
disp(stat.ranovatbl);
fprintf('Simple main effect Go   (GoF vs GoS):     t(%d)=%.4f, p=%.4f\n', ...
    stat.sme_Go.stats.df,   stat.sme_Go.stats.tstat,   stat.sme_Go.p);
fprintf('Simple main effect NoGo (NoGoF vs NoGoS): t(%d)=%.4f, p=%.4f\n', ...
    stat.sme_NoGo.stats.df, stat.sme_NoGo.stats.tstat, stat.sme_NoGo.p);
fprintf('Results saved to: %s\n', res_dir);

% =========================================================================
% local helper: format a table to string (compatible with older MATLAB)
% =========================================================================
function s = formattable(T)
    s = evalc('disp(T)');
    s = regexprep(s, '<[^>]+>', '');
end
