%% stat_rt_pitch.m  [supplemental]
% 2-way mixed ANOVA for response time (Go trials only)
%   Between: Group (exp / nov)
%   Within:  Pitch (Go-F=ff correct vs Go-S=cc correct)
%
% task column coding in trialinfo{pi}(:,1):
%   +1 = ff correct  (Go-F)
%   +4 = cc correct  (Go-S)
%   column 2 = RT (seconds)
%
% Output: result/stat_rt_pitch/stat.mat and stat_result.txt

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'trialinfo');   % raw trialinfo
res_dir  = fullfile(prj_dir, 'result', 'stat_rt_pitch');
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

% -------------------------------------------------------------------------
% load data
% -------------------------------------------------------------------------
load(fullfile(data_dir, 'exp.mat'));   % -> exp
load(fullfile(data_dir, 'nov.mat'));   % -> nov

% -------------------------------------------------------------------------
% collect mean RT per participant per pitch type
%   RT_GoF : task==+1, column 2
%   RT_GoS : task==+4, column 2
% -------------------------------------------------------------------------
n_subj = 12;

exp.m_rt_pitch = zeros(n_subj, 2);   % [RT_GoF, RT_GoS]
exp.rts_gof    = cell(1, n_subj);
exp.rts_gos    = cell(1, n_subj);

nov.m_rt_pitch = zeros(n_subj, 2);
nov.rts_gof    = cell(1, n_subj);
nov.rts_gos    = cell(1, n_subj);

for pi = 1:n_subj
    d_exp = exp.trialinfo{1, pi};
    exp.rts_gof{pi}      = d_exp(d_exp(:,1) == 1, 2);
    exp.rts_gos{pi}      = d_exp(d_exp(:,1) == 4, 2);
    exp.m_rt_pitch(pi,1) = mean(exp.rts_gof{pi});
    exp.m_rt_pitch(pi,2) = mean(exp.rts_gos{pi});
end

for pi = 1:n_subj
    d_nov = nov.trialinfo{1, pi};
    nov.rts_gof{pi}      = d_nov(d_nov(:,1) == 1, 2);
    nov.rts_gos{pi}      = d_nov(d_nov(:,1) == 4, 2);
    nov.m_rt_pitch(pi,1) = mean(nov.rts_gof{pi});
    nov.m_rt_pitch(pi,2) = mean(nov.rts_gos{pi});
end

% save intermediate data
save(fullfile(res_dir, 'exp.mat'), 'exp', '-v7.3');
save(fullfile(res_dir, 'nov.mat'), 'nov', '-v7.3');

% -------------------------------------------------------------------------
% descriptive statistics  [M, SD]  per cell
% -------------------------------------------------------------------------
desc.M_exp_GoF  = mean(exp.m_rt_pitch(:,1));
desc.SD_exp_GoF = std(exp.m_rt_pitch(:,1));
desc.M_exp_GoS  = mean(exp.m_rt_pitch(:,2));
desc.SD_exp_GoS = std(exp.m_rt_pitch(:,2));

desc.M_nov_GoF  = mean(nov.m_rt_pitch(:,1));
desc.SD_nov_GoF = std(nov.m_rt_pitch(:,1));
desc.M_nov_GoS  = mean(nov.m_rt_pitch(:,2));
desc.SD_nov_GoS = std(nov.m_rt_pitch(:,2));

% -------------------------------------------------------------------------
% build table for fitrm
%   rows = 24 participants
%   columns: group (categorical), RT_GoF, RT_GoS
% -------------------------------------------------------------------------
var_names = {'group', 'RT_GoF', 'RT_GoS'};
var_types = {'categorical', 'double', 'double'};

tbl = table('Size', [0, length(var_names)], ...
            'VariableTypes', var_types, ...
            'VariableNames', var_names);

for pi = 1:n_subj
    tbl(end+1, :) = {categorical({'exp'}), ...
                     exp.m_rt_pitch(pi,1), exp.m_rt_pitch(pi,2)};
end
for pi = 1:n_subj
    tbl(end+1, :) = {categorical({'nov'}), ...
                     nov.m_rt_pitch(pi,1), nov.m_rt_pitch(pi,2)};
end

% -------------------------------------------------------------------------
% 2-way mixed ANOVA via fitrm + ranova
%   Within: Pitch (GoF / GoS)
%   Between: Group (exp / nov)
% -------------------------------------------------------------------------
within_design = table( ...
    categorical({'GoF'; 'GoS'}), ...
    'VariableNames', {'Pitch'});

rm = fitrm(tbl, 'RT_GoF-RT_GoS ~ group', 'WithinDesign', within_design);
stat.ranovatbl = ranova(rm, 'WithinModel', 'Pitch');

% -------------------------------------------------------------------------
% post-hoc: paired t-test for Pitch main effect (if significant, p<0.05)
% -------------------------------------------------------------------------
all_GoF = [exp.m_rt_pitch(:,1); nov.m_rt_pitch(:,1)];
all_GoS = [exp.m_rt_pitch(:,2); nov.m_rt_pitch(:,2)];

[stat.posthoc.h, stat.posthoc.p, stat.posthoc.ci, stat.posthoc.stats] = ...
    ttest(all_GoF, all_GoS);

% -------------------------------------------------------------------------
% save mat
% -------------------------------------------------------------------------
stat.tbl  = tbl;
stat.desc = desc;
save(fullfile(res_dir, 'stat.mat'), 'stat', '-v7.3');

% -------------------------------------------------------------------------
% write txt report
% -------------------------------------------------------------------------
fid = fopen(fullfile(res_dir, 'stat_result.txt'), 'w');

fprintf(fid, '=== 2-way mixed ANOVA: RT (Go trials only) ===\n');
fprintf(fid, 'Between: Group (exp / nov, n=12 each)\n');
fprintf(fid, 'Within:  Pitch (Go-F=ff / Go-S=cc)\n\n');

fprintf(fid, '--- Descriptive statistics: Mean RT (s) +/- SD ---\n');
fprintf(fid, '         GoF (ff)              GoS (cc)\n');
fprintf(fid, 'Exp   %.4f (%.4f)       %.4f (%.4f)\n', ...
    desc.M_exp_GoF, desc.SD_exp_GoF, desc.M_exp_GoS, desc.SD_exp_GoS);
fprintf(fid, 'Nov   %.4f (%.4f)       %.4f (%.4f)\n', ...
    desc.M_nov_GoF, desc.SD_nov_GoF, desc.M_nov_GoS, desc.SD_nov_GoS);
fprintf(fid, '\n');

fprintf(fid, '--- ranova table ---\n');
fprintf(fid, '%s\n\n', formattable(stat.ranovatbl));

fprintf(fid, '--- Post-hoc: paired t-test GoF vs GoS (overall, alpha=0.05) ---\n');
fprintf(fid, 't(%d)=%.4f, p=%.4f, h=%d\n', ...
    stat.posthoc.stats.df, stat.posthoc.stats.tstat, ...
    stat.posthoc.p,        stat.posthoc.h);

fclose(fid);

% -------------------------------------------------------------------------
% console summary
% -------------------------------------------------------------------------
disp('=== 2-way mixed ANOVA: RT (Go trials only) ===');
disp(stat.ranovatbl);
fprintf('Post-hoc paired t-test GoF vs GoS: t(%d)=%.4f, p=%.4f\n', ...
    stat.posthoc.stats.df, stat.posthoc.stats.tstat, stat.posthoc.p);
fprintf('Results saved to: %s\n', res_dir);

% =========================================================================
% local helper: format a table to string (compatible with older MATLAB)
% =========================================================================
function s = formattable(T)
    s = evalc('disp(T)');
    s = regexprep(s, '<[^>]+>', '');
end
