% fig_compare_electrode_layouts.m
% Compare electrode layouts from two elc files using ft_plot_layout.
%   (A) standard_1005.elc                     FieldTrip generic 10-05
%   (B) standard_waveguard64_1005_rotated.elc  ANT waveguard 64ch (CCW 90deg corrected)
%
% Output: result/fig_electrode_map/compare_layouts.svg

clear; clc;

prj_dir = 'C:\Users\kaito\workspace\exp1_EEG_analysis';

active_channels = {
    'Fp1','Fp2','Fpz', ...
    'AF3','AF4','AF7','AF8', ...
    'F1','F2','F3','F4','F5','F6','F7','F8','Fz', ...
    'FC1','FC2','FC3','FC4','FC5','FC6','FCz', ...
    'FT7','FT8', ...
    'C1','C2','C3','C4','C5','C6','Cz', ...
    'T7','T8', ...
    'CP1','CP2','CP3','CP4','CP5','CP6', ...
    'TP7','TP8', ...
    'P1','P2','P3','P4','P5','P6','P7','P8','Pz', ...
    'PO3','PO4','PO5','PO6','PO7','PO8','POz', ...
    'O1','O2','Oz', ...
    'CPz','AFz' ...
};

elc_files = {
    'C:\Users\kaito\fieldtrip\template\electrode\standard_1005.elc', ...
    'C:\Users\kaito\fieldtrip\template\electrode\standard_waveguard64_1005_rotated.elc'
};
panel_titles = {
    'standard\_1005.elc  [FieldTrip generic]', ...
    'standard\_waveguard64\_1005\_rotated.elc  [ANT waveguard 64ch]'
};

fig = figure('Units','centimeters','Position',[0 0 36 20]);

for p = 1:2
    cfg         = [];
    cfg.elec    = ft_read_sens(elc_files{p});
    cfg.channel = active_channels;
    lay = ft_prepare_layout(cfg);

    subplot(1, 2, p);
    ft_plot_layout(lay, 'label', 'yes', 'box', 'no', 'pointsize', 8);
    title(panel_titles{p}, 'Interpreter','tex', 'FontSize', 9);
end

out_dir = fullfile(prj_dir, 'result', 'fig_electrode_map');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
print(fig, '-dsvg', fullfile(out_dir, 'compare_layouts.svg'));
close(fig);
fprintf('Saved.\n');
