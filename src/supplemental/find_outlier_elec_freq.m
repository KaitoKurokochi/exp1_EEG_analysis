% find_outlier_elec_freq.m
% Detect electrodes with outlier power per participant in frequency analysis.
%
% For each frequency band x condition, computes mean power (0-500 ms,
% averaged over frequencies within band) per channel per participant, then
% z-scores within each group across participants. Channels with |z| > z_thresh
% are flagged as outliers.
%
% Input:  result/freq_per_subj/  (produced by stat_freq_diff_cbpt.m Section 1)
% Output: result/fig_outlier_elec_freq/
%   heatmap_{cond}_{band}.png      — participants x channels z-score heatmap
%   topo_outlier_{cond}_{band}.png — topomap of per-channel outlier counts
%   outlier_summary.csv            — list of (subject, channel, z-score)

clear;
config;

subj_dir = fullfile(prj_dir, 'result', 'freq_per_subj');
res_dir  = fullfile(prj_dir, 'result', 'fig_outlier_elec_freq');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end

bands = { ...
    [4  7],   'Theta'; ...
    [7  13],  'alpha'; ...
    [13 30],  'beta'; ...
    [30 45],  'Low_gamma'; ...
    [60 90],  'High_gamma'};
n_bands = size(bands, 1);

z_thresh   = 3.0;   % |z-score| threshold for outlier
n_subj     = 12;
cond_flds  = {'freq_go', 'freq_nogo'};
cond_names = {'go',      'nogo'};

% ---- get channel list from first available file ----
chan_eeg = [];
ref_struct = [];
for gi = 1:length(groups)
    for pi = 1:n_subj
        fname = fullfile(subj_dir, [groups{gi}, num2str(pi), '.mat']);
        if exist(fname, 'file')
            s = load(fname, 'freq_go');
            all_labels = s.freq_go.label;
            keep = cellfun(@(x) isempty(regexpi(x, 'eog')), all_labels);
            chan_eeg   = all_labels(keep);
            ref_struct = s.freq_go;
            break;
        end
    end
    if ~isempty(chan_eeg), break; end
end

if isempty(chan_eeg)
    error('No freq_per_subj files found. Run stat_freq_diff_cbpt.m Section 1 first.');
end
n_chans = length(chan_eeg);

% subject ID list: groups{1} first, then groups{2}
all_ids = {};
grp_idx = zeros(0, 1); % group index for each row in stacked matrix
for gi = 1:length(groups)
    for pi = 1:n_subj
        all_ids{end+1} = [groups{gi}, num2str(pi)]; %#ok<AGROW>
        grp_idx(end+1) = gi; %#ok<AGROW>
    end
end
n_all = length(all_ids);

% open CSV
fid = fopen(fullfile(res_dir, 'outlier_summary.csv'), 'w');
fprintf(fid, 'condition,band,subject,channel,z_score\n');

% ---- main loop ----
for ci = 1:length(cond_names)
    cond_fld  = cond_flds{ci};
    cond_name = cond_names{ci};

    for bi = 1:n_bands
        band_range = bands{bi, 1};
        band_name  = bands{bi, 2};
        fprintf('--- %s / %s ---\n', cond_name, band_name);

        % build power matrix [n_all x n_chans]
        pow_mat = nan(n_all, n_chans);

        for si = 1:n_all
            fname = fullfile(subj_dir, [all_ids{si}, '.mat']);
            if ~exist(fname, 'file'), continue; end
            s  = load(fname, cond_fld);
            fd = s.(cond_fld);

            cfg_sel           = [];
            cfg_sel.frequency = band_range;
            cfg_sel.latency   = [0.0, 0.5];
            cfg_sel.channel   = chan_eeg;
            fd_sel = ft_selectdata(cfg_sel, fd);

            % align channel order to chan_eeg
            [~, ch_ord] = ismember(chan_eeg, fd_sel.label);
            valid = ch_ord > 0;

            % mean over freq and time -> scalar per channel
            pow3d = fd_sel.powspctrm; % [n_chans_sel x n_freqs x n_times]
            mp    = mean(reshape(pow3d, size(pow3d,1), []), 2); % [n_chans_sel x 1]

            pow_mat(si, valid) = mp(ch_ord(valid))';
        end

        % z-score within each group independently
        z_mat = nan(n_all, n_chans);
        for gi = 1:length(groups)
            rows = (grp_idx == gi);
            mu   = nanmean(pow_mat(rows, :), 1);
            sd   = nanstd(pow_mat(rows, :), 0, 1);
            z_mat(rows, :) = (pow_mat(rows, :) - mu) ./ (sd + eps);
        end

        outlier_mask = abs(z_mat) > z_thresh;

        % write outliers to CSV
        [oi, oj] = find(outlier_mask);
        for k = 1:length(oi)
            fprintf(fid, '%s,%s,%s,%s,%.3f\n', ...
                cond_name, band_name, all_ids{oi(k)}, chan_eeg{oj(k)}, ...
                z_mat(oi(k), oj(k)));
        end

        % ----- Heatmap -----
        row_h    = 16;
        margin_l = 90;   % left margin for y-labels
        margin_b = 120;  % bottom margin for x-labels
        margin_t = 50;
        margin_r = 80;   % right margin for colorbar
        cell_w   = max(8, min(20, round(900 / n_chans)));

        fig_w = margin_l + n_chans * cell_w + margin_r;
        fig_h = margin_b + n_all * row_h    + margin_t;

        fig = figure('Visible', 'off', 'Units', 'pixels', ...
            'Position', [0, 0, fig_w, fig_h]);
        ax = axes('Units', 'pixels', ...
            'Position', [margin_l, margin_b, n_chans*cell_w, n_all*row_h]);

        imagesc(ax, z_mat);
        colormap(ax, local_redblue(256));
        clim(ax, [-5, 5]);
        cb = colorbar(ax);
        ylabel(cb, 'Z-score', 'FontSize', 9);

        hold(ax, 'on');

        % outlier markers
        for k = 1:length(oi)
            text(ax, oj(k), oi(k), '\times', 'Color', 'k', 'FontSize', 6, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold');
        end

        % group separator
        sep_y = sum(grp_idx == 1) + 0.5;
        line(ax, [0.5, n_chans+0.5], [sep_y, sep_y], 'Color', 'k', 'LineWidth', 2);

        set(ax, 'YTick', 1:n_all, 'YTickLabel', all_ids, 'FontSize', 7, ...
            'TickLength', [0, 0]);
        set(ax, 'XTick', 1:n_chans, 'XTickLabel', chan_eeg, ...
            'XTickLabelRotation', 90, 'FontSize', 6);
        xlabel(ax, 'Channel');
        ylabel(ax, 'Participant');
        title(ax, sprintf('Z-score of mean power: %s – %s  (|z|>%.0f marked ×)', ...
            band_name, cond_name, z_thresh), 'FontSize', 10);

        out_h = fullfile(res_dir, sprintf('heatmap_%s_%s.png', cond_name, band_name));
        exportgraphics(fig, out_h, 'Resolution', 150);
        close(fig);
        fprintf('  saved: %s\n', out_h);

        % ----- Topomap of outlier count per channel -----
        outlier_count = sum(outlier_mask, 1)'; % [n_chans x 1]

        topo_data.label  = chan_eeg;
        topo_data.avg    = outlier_count;   % [n_chans x 1]
        topo_data.time   = 0;
        topo_data.dimord = 'chan_time';

        fig2 = figure('Visible', 'off', 'Units', 'pixels', ...
            'Position', [0, 0, 420, 380]);
        cfg_t            = [];
        cfg_t.colorbar   = 'yes';
        cfg_t.layout     = 'easycapM11.mat';
        cfg_t.zlim       = [0, max(max(outlier_count(:)), 1)];
        cfg_t.comment    = 'no';
        cfg_t.colormap   = 'hot';
        cfg_t.title      = sprintf('%s – %s: outlier count', band_name, cond_name);
        ft_topoplotER(cfg_t, topo_data);

        out_t = fullfile(res_dir, sprintf('topo_outlier_%s_%s.png', cond_name, band_name));
        exportgraphics(fig2, out_t, 'Resolution', 150);
        close(fig2);
        fprintf('  saved: %s\n', out_t);
    end
end

fclose(fid);
fprintf('\nDone. Outlier summary -> %s\n', fullfile(res_dir, 'outlier_summary.csv'));

% -----------------------------------------------------------------------
function cmap = local_redblue(n)
% Diverging blue-white-red colormap centered at 0.
half = floor(n / 2);
t    = linspace(0, 1, half)';
blue_to_white = [t, t, ones(half, 1)];
white_to_red  = [ones(half, 1), 1-t, 1-t];
cmap = [blue_to_white; white_to_red];
if size(cmap, 1) < n
    cmap(end+1, :) = cmap(end, :);
end
end
