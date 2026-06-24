%% statistics of response time (go-condition)
% compare between groups - indep T test

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'trialinfo'); % set data dir
res_dir = fullfile(prj_dir, 'result', 'stat_rt'); % set res dir
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

% read data
load(fullfile(data_dir, 'exp.mat'));
load(fullfile(data_dir, 'nov.mat'));

% collect RT 
% exp
exp.m_rt = zeros(1, 12);
exp.rts = cell(1, 12);
for pi = 1:12
    data = exp.trialinfo{1, pi};
    exp.rts{1, pi} = data((data(:, 1) == 1 | data(:, 1) == 4), 2);
    exp.m_rt(1, pi) = mean(exp.rts{1, pi});
end
% nov
nov.m_rt = zeros(1, 12);
nov.rts = cell(1, 12);
for pi = 1:12
    data = nov.trialinfo{1, pi};
    nov.rts{1, pi} = data((data(:, 1) == 1 | data(:, 1) == 4), 2);
    nov.m_rt(1, pi) = mean(nov.rts{1, pi});
end

% stat
stat = [];
[stat.h, stat.p, stat.ci, stat.stats] = ttest2(exp.m_rt, nov.m_rt);

% -------------------------------------------------------------------------
% Cohen's d  (effect size for independent-samples t-test)
%   d = (mean_exp - mean_nov) / pooled_SD
%   pooled_SD = sqrt( ((n1-1)*var1 + (n2-1)*var2) / (n1+n2-2) )
% -------------------------------------------------------------------------
n1 = numel(exp.m_rt);
n2 = numel(nov.m_rt);
pooled_sd = sqrt( ((n1-1)*var(exp.m_rt) + (n2-1)*var(nov.m_rt)) / (n1+n2-2) );
stat.cohens_d = (mean(exp.m_rt) - mean(nov.m_rt)) / pooled_sd;

fprintf('\n--- t-test result (RT) ---\n');
fprintf('  t(%d) = %.4f,  p = %.4f\n', stat.stats.df, stat.stats.tstat, stat.p);
fprintf('--- effect size ---\n');
fprintf('  Cohen''s d = %.4f\n', stat.cohens_d);

% save data
stat.exp = exp;
stat.nov = nov;
save(fullfile(res_dir, 'stat.mat'), 'stat');


