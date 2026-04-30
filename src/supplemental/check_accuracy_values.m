% check_accuracy_values.m  [supplemental]
% Displays overall accuracy per group.
% Requires stat_accuracy.m to have been run first.
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'stat_accuracy');
load(fullfile(data_dir, 'exp.mat'));
load(fullfile(data_dir, 'nov.mat'));

s_trls_exp     = sum(exp.gng_trls);
s_cor_trls_exp = sum(exp.gng_cor_trls);
ac_exp         = s_cor_trls_exp ./ s_trls_exp;

s_trls_nov     = sum(nov.gng_trls);
s_cor_trls_nov = sum(nov.gng_cor_trls);
ac_nov         = s_cor_trls_nov ./ s_trls_nov;

fprintf('Exp  Go: %.4f  NoGo: %.4f\n', ac_exp(1), ac_exp(2));
fprintf('Nov  Go: %.4f  NoGo: %.4f\n', ac_nov(1), ac_nov(2));
