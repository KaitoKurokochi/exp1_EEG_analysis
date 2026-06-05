% erp_to_freq_alpha: wavelet transform for alpha band (7-13Hz, log-spaced, 5 points)
% cfg.foi  : logspace(log10(7), log10(13), 5) → ~[7.0, 8.1, 9.3, 10.7, 13.0] Hz
% cfg.width: power law from Minami & Amano (2017) [3-12 cycles for 3-40 Hz]
%            width(f) = 3 * (f/3)^(log(12/3)/log(40/3)) ≈ 3 * (f/3)^0.535
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
        cfg.foi         = logspace(log10(7), log10(13), 5);
        cfg.width       = 3 * (cfg.foi / 3) .^ (log(12/3) / log(40/3)); % Minami & Amano (2017): width(f) = 3*(f/3)^0.535
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
