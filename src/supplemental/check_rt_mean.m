% check_rt_mean.m  [supplemental]
% Displays mean RT per group.
% Requires stat_rt.m to have been run first.
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'stat_rt');
load(fullfile(data_dir, 'stat.mat'));

m_rt_exp = mean(stat.exp.m_rt);
m_rt_nov = mean(stat.nov.m_rt);

fprintf('Mean RT  Exp: %.4f s\n', m_rt_exp);
fprintf('Mean RT  Nov: %.4f s\n', m_rt_nov);
