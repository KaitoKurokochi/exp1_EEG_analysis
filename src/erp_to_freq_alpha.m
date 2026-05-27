% erp_to_freq_alpha: wavelet transform for alpha band (7-13Hz, 1Hz steps)
% cfg.foi  : 7:1:13 Hz
% cfg.width: logspace(log10(5.67), log10(7.78), 7) — mirrors original full-band scaling
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond');
res_dir  = fullfile(prj_dir, 'result', 'freq_group_cond_alpha');
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

for gi = 1:length(groups)
    for ci = 1:length(conditions)
        fname = fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat']);
        disp('loading...');
        load(fname);

        % wavelet transform
        cfg = [];
        cfg.method      = 'wavelet';
        cfg.output      = 'pow';
        cfg.keeptrials  = 'yes';
        cfg.foi         = 7:1:13;
        cfg.width       = logspace(log10(5.67), log10(7.78), length(cfg.foi)); % review 
        cfg.toi         = round((data.time{1}(1) : 0.05 : data.time{1}(end)) * data.fsample) / data.fsample;
        freq = ft_freqanalysis(cfg, data);

        % baseline correction
        cfg = [];
        cfg.baseline     = [-0.1 0.0];
        cfg.baselinetype = 'db';
        freq = ft_freqbaseline(cfg, freq);

        save(fullfile(res_dir, [groups{gi}, '_', conditions{ci}, '.mat']), 'freq', '-v7.3');
        fprintf('Saved: %s_%s\n', groups{gi}, conditions{ci});
    end
end

disp('Done. Results saved to freq_group_cond_alpha/');
