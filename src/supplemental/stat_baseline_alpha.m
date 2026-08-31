% stat_baseline_alpha.m
% Check whether baseline alpha power (−100 to 0 ms) differs between groups.
% Unit of analysis: participant (n = 12 per group).
% For each participant, all segments are pooled, wavelet is applied without
% dB normalization, and power is averaged over baseline window, alpha band,
% and all channels to yield one scalar per participant.
% Input:  result/prepro3/{group}{pi}-{si}.mat
% Output: console summary (mean, SD, t-test result per condition)

clear;
config;

data_dir  = fullfile(prj_dir, 'result', 'prepro3');
n_subj    = 12;
n_seg     = 5;
band_freq = [7 13];

for ci = 1:length(conditions)
    cond = conditions{ci};
    fprintf('\n=== condition: %s ===\n', cond);

    cond_label = conditions{ci}; % 'go' or 'nogo'

    for gi = 1:length(groups)
        grp = groups{gi};
        subj_means = nan(n_subj, 1);

        for pi = 1:n_subj
            seg_pow = [];

            for si = 1:n_seg
                fname = fullfile(data_dir, sprintf('%s%d-%d.mat', grp, pi, si));
                if ~exist(fname, 'file'), continue; end

                load(fname); % loads 'data'

                % select trials for this condition
                % trialinfo column 1: trial type (1=go, 2=nogo assumed; adjust if needed)
                if strcmp(cond_label, 'go')
                    sel_trl = data.trialinfo(:, 1) == 1;
                else
                    sel_trl = data.trialinfo(:, 1) == 2;
                end

                if sum(sel_trl) == 0, continue; end

                cfg_sel         = [];
                cfg_sel.trials  = find(sel_trl);
                data_cond = ft_selectdata(cfg_sel, data);

                % wavelet transform WITHOUT baseline correction
                cfg_tf            = [];
                cfg_tf.method     = 'wavelet';
                cfg_tf.output     = 'pow';
                cfg_tf.keeptrials = 'yes';
                cfg_tf.foi        = logspace(log10(7), log10(13), 5);
                cfg_tf.width      = 3 * (cfg_tf.foi / 3) .^ (log(12/3) / log(40/3));
                cfg_tf.toi        = round((data_cond.time{1}(1) : 0.05 : data_cond.time{1}(end)) * data_cond.fsample) / data_cond.fsample;
                freq = ft_freqanalysis(cfg_tf, data_cond);

                % select baseline window and alpha band
                cfg_bl           = [];
                cfg_bl.frequency = band_freq;
                cfg_bl.latency   = [-0.1 0.0];
                freq_bl = ft_selectdata(cfg_bl, freq);

                % average over trials, time, frequency, channels
                pow_mean = mean(freq_bl.powspctrm(:));
                seg_pow  = [seg_pow; pow_mean]; %#ok<AGROW>
            end

            if ~isempty(seg_pow)
                subj_means(pi) = mean(seg_pow);
            end
        end

        if gi == 1
            exp_means = subj_means;
        else
            nov_means = subj_means;
        end

        fprintf('%s: mean = %.4f, SD = %.4f\n', grp, mean(subj_means, 'omitnan'), std(subj_means, 'omitnan'));
    end

    % independent-samples t-test (participant level, n=12 vs 12)
    [~, p, ~, stats] = ttest2(exp_means, nov_means);
    fprintf('t(%d) = %.2f, p = %.4f\n', stats.df, stats.tstat, p);
end

disp('Done.');
