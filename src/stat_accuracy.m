%% statistics accuracy of tasks  
% compare between groups, with two-way ANOVA

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'trialinfo'); % set data dir
res_dir = fullfile(prj_dir, 'result', 'stat_accuracy'); % set res dir
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

% read data
load(fullfile(data_dir, 'exp.mat'));
load(fullfile(data_dir, 'nov.mat'));

% exp
disp('--- start exp ---');
% calculate accuracy - each
disp('--- calculate accuracy ---')
exp.cond_trls = zeros(12, length(conditions));
exp.cond_cor_trls = zeros(12, length(conditions));
exp.gng_trls = zeros(12, 2);
exp.gng_cor_trls = zeros(12, 2);

for pi = 1:12
    % each cond
    for ci = 1:length(conditions)
        exp.cond_cor_trls(pi, ci) = nnz(exp.trialinfo{pi}(:, 1) == ci);
        exp.cond_trls(pi, ci) = nnz(exp.trialinfo{pi}(:, 1) == ci | exp.trialinfo{pi}(:, 1) == -ci);
    end
    % go/nogo
    exp.gng_cor_trls(pi, 1) = nnz(exp.trialinfo{pi}(:, 1) == 1 | exp.trialinfo{pi}(:, 1) == 4);
    exp.gng_trls(pi, 1) = nnz(exp.trialinfo{pi}(:, 1) == 1 | exp.trialinfo{pi}(:, 1) == 4 | exp.trialinfo{pi}(:, 1) == -1 | exp.trialinfo{pi}(:, 1) == -4);
    exp.gng_cor_trls(pi, 2) = nnz(exp.trialinfo{pi}(:, 1) == 2 | exp.trialinfo{pi}(:, 1) == 3);
    exp.gng_trls(pi, 2) = nnz(exp.trialinfo{pi}(:, 1) == 2 | exp.trialinfo{pi}(:, 1) == 3 | exp.trialinfo{pi}(:, 1) == -2 | exp.trialinfo{pi}(:, 1) == -3);
end
exp.p_cond_accuracy = exp.cond_cor_trls ./ exp.cond_trls; % each p, each cond
exp.p_gng_accuracy = exp.gng_cor_trls ./ exp.gng_trls;
exp.p_accuracy = sum(exp.cond_cor_trls, 2) ./ sum(exp.cond_trls, 2); % each p

% save data
save(fullfile(res_dir, 'exp.mat'), 'exp', '-v7.3');

% nov
disp('--- start nov ---');

% calculate accuracy
disp('--- calculate accuracy ---')
nov.cond_trls = zeros(12, length(conditions));
nov.cond_cor_trls = zeros(12, length(conditions));
nov.gng_trls = zeros(12, 2);
nov.gng_cor_trls = zeros(12, 2);

for pi = 1:12
    % each cond
    for ci = 1:length(conditions)
        nov.cond_cor_trls(pi, ci) = nnz(nov.trialinfo{pi}(:, 1) == ci);
        nov.cond_trls(pi, ci) = nnz(nov.trialinfo{pi}(:, 1) == ci | nov.trialinfo{pi}(:, 1) == -ci);
    end
    % go/nogo
    nov.gng_cor_trls(pi, 1) = nnz(nov.trialinfo{pi}(:, 1) == 1 | nov.trialinfo{pi}(:, 1) == 4);
    nov.gng_trls(pi, 1) = nnz(nov.trialinfo{pi}(:, 1) == 1 | nov.trialinfo{pi}(:, 1) == 4 | nov.trialinfo{pi}(:, 1) == -1 | nov.trialinfo{pi}(:, 1) == -4);
    nov.gng_cor_trls(pi, 2) = nnz(nov.trialinfo{pi}(:, 1) == 2 | nov.trialinfo{pi}(:, 1) == 3);
    nov.gng_trls(pi, 2) = nnz(nov.trialinfo{pi}(:, 1) == 2 | nov.trialinfo{pi}(:, 1) == 3 | nov.trialinfo{pi}(:, 1) == -2 | nov.trialinfo{pi}(:, 1) == -3);
end
nov.p_cond_accuracy = nov.cond_cor_trls ./ nov.cond_trls; % each p, each cond
nov.p_gng_accuracy = nov.gng_cor_trls ./ nov.gng_trls;
nov.p_accuracy = sum(nov.cond_cor_trls, 2) ./ sum(nov.cond_trls, 2); % each p

% save data
save(fullfile(res_dir, 'nov.mat'), 'nov', '-v7.3');

% stat
stat = [];
var_names = {'group', 'go_accuracy', 'nogo_accuracy'};
var_types = {'categorical', 'double', 'double'};

stat.tbl = table('Size', [0, length(var_names)], ...
            'VariableTypes', var_types, ...
            'VariableNames', var_names);

% exp 
for pi = 1:12
    new_row = {categorical({'exp'}), exp.p_gng_accuracy(pi, 1), exp.p_gng_accuracy(pi, 2)};
    stat.tbl(end+1, :) = new_row;
end
% nov 
for pi = 1:12
    new_row = {categorical({'nov'}), nov.p_gng_accuracy(pi, 1), nov.p_gng_accuracy(pi, 2)};
    stat.tbl(end+1, :) = new_row;
end

% 2way anova
within_struct = table({'Go'; 'NoGo'}, 'VariableNames', {'Condition'});
rm = fitrm(stat.tbl, 'go_accuracy-nogo_accuracy ~ group', 'WithinDesign', within_struct);
stat.ranovatbl = ranova(rm, 'WithinModel', 'Condition');
% multi compare
stat.mc = multcompare(rm, 'group', 'By', 'Condition', 'ComparisonType', 'bonferroni');

% -------------------------------------------------------------------------
% partial eta-squared  (SumSq_effect / (SumSq_effect + SumSq_error))
%   ranova row names:
%     'group'              = Group main effect (between)      error: 'Error'
%     '(Intercept):Condition'  = Condition main effect (within) error: 'Error(Condition)'
%     'group:Condition'    = Group x Condition interaction    error: 'Error(Condition)'
% -------------------------------------------------------------------------
row_names = stat.ranovatbl.Properties.RowNames;

ss_group     = stat.ranovatbl{'group',                   'SumSq'};
ss_cond      = stat.ranovatbl{'(Intercept):Condition',   'SumSq'};
ss_inter     = stat.ranovatbl{'group:Condition',         'SumSq'};
ss_err_btw   = stat.ranovatbl{'Error',                   'SumSq'};
ss_err_wthn  = stat.ranovatbl{'Error(Condition)',        'SumSq'};

stat.petasq_group  = ss_group  / (ss_group  + ss_err_btw);
stat.petasq_cond   = ss_cond   / (ss_cond   + ss_err_wthn);
stat.petasq_inter  = ss_inter  / (ss_inter  + ss_err_wthn);

fprintf('\n--- ranova result ---\n');
disp(stat.ranovatbl);
fprintf('--- partial eta-squared ---\n');
fprintf('  Group (between):         partial eta2 = %.4f\n', stat.petasq_group);
fprintf('  Condition (within):      partial eta2 = %.4f\n', stat.petasq_cond);
fprintf('  Group x Condition:       partial eta2 = %.4f\n', stat.petasq_inter);

save(fullfile(res_dir, 'stat.mat'), 'stat', '-v7.3');
