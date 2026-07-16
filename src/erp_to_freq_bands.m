% erp_to_freq_bands.m
% Band-specific wavelet time-frequency analysis for six frequency bands.
%
% For each band, five log-spaced frequency points are used within the band
% (following Minami et al., 2024).  The wavelet width is set by the power-law
% function of Minami & Amano (2017): width(f) = 3*(f/3)^0.535.
%
% Frequency bands (Minami et al., 2024):
%   delta      1– 4 Hz  → result/freq_group_cond_delta/
%   theta      4– 7 Hz  → result/freq_group_cond_theta/
%   alpha      7–13 Hz  → result/freq_group_cond_alpha/
%   beta      13–30 Hz  → result/freq_group_cond_beta/
%   low-gamma 30–45 Hz  → result/freq_group_cond_lowgamma/
%   high-gamma60–95 Hz  → result/freq_group_cond_highgamma/
%
% Prerequisites: prepro3_ica.m (ERP epoched data in result/erp_group_cond/)

clear;
config;

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond');

% Bands: {[f_lo f_hi], display_name, output_directory}
bands = { ...
    [1  4],  'delta',     'freq_group_cond_delta'; ...
    [4  7],  'theta',     'freq_group_cond_theta'; ...
    [7  13], 'alpha',     'freq_group_cond_alpha'; ...
    [13 30], 'beta',      'freq_group_cond_beta'; ...
    [30 45], 'lowgamma',  'freq_group_cond_lowgamma'; ...
    [60 95], 'highgamma', 'freq_group_cond_highgamma'};
n_bands = size(bands, 1);

for bi = 1:n_bands
    band_freq = bands{bi, 1};
    band_name = bands{bi, 2};
    res_dir   = fullfile(prj_dir, 'result', bands{bi, 3});
    if ~exist(res_dir, 'dir'), mkdir(res_dir); end

    % 5 log-spaced frequency points within the band (Minami et al., 2024)
    foi = logspace(log10(band_freq(1)), log10(band_freq(2)), 5);

    fprintf('=== %s (%.0f–%.0f Hz): foi = [', band_name, band_freq(1), band_freq(2));
    fprintf(' %.2f', foi);
    fprintf(' ] Hz ===\n');

    for gi = 1:length(groups)
        for ci = 1:length(conditions)
            fname = fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat']);
            fprintf('  loading: %s_%s ... ', groups{gi}, conditions{ci});
            load(fname);

            % Wavelet transform — 5 band-specific frequency points
            cfg             = [];
            cfg.method      = 'wavelet';
            cfg.output      = 'pow';
            cfg.keeptrials  = 'yes';
            cfg.foi         = foi;
            % Width function: Minami & Amano (2017) — width(f) = 3*(f/3)^0.535
            cfg.width       = 3 * (cfg.foi / 3) .^ (log(12/3) / log(40/3));
            cfg.toi         = round((data.time{1}(1) : 0.05 : data.time{1}(end)) * data.fsample) / data.fsample;
            freq            = ft_freqanalysis(cfg, data);

            % Decibel baseline correction (−100 to 0 ms)
            cfg              = [];
            cfg.baseline     = [-0.1 0.0];
            cfg.baselinetype = 'db';
            freq             = ft_freqbaseline(cfg, freq);

            out_name = fullfile(res_dir, [groups{gi}, '_', conditions{ci}, '.mat']);
            save(out_name, 'freq', '-v7.3');
            fprintf('saved.\n');
        end
    end
    fprintf('[%s] Done.\n\n', band_name);
end

disp('All bands complete.');
