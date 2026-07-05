% plot_electrode_map.m
% Generates an SVG electrode diagram for exp1 EEG study.
%
% Rendering approach:
%   ft_topoplotER (style='blank', marker='off') is used to draw the head
%   outline (circle, nose, ears) via the easycapM11 layout.
%   Electrode circles and labels are then overlaid on the resulting axes
%   using coordinates extracted from the same layout.
%
% Electrode configuration:
%   - Active channels (n = 63): 10-20 extended system, easycapM11 cap
%   - Reference electrode (CPz): re-referenced offline; shown in blue
%   - Ground electrode (AFz): shown in gray
%
% Output:
%   result/fig_electrode_map/electrode_map.svg
%
% Requirements:
%   - FieldTrip toolbox on MATLAB path

clear; clc;

prj_dir = 'C:\Users\kaito\workspace\exp1_EEG_analysis';

% -------------------------------------------------------------------------
% 1. Load easycapM11 layout and extract electrode positions
% -------------------------------------------------------------------------
cfg_layout        = [];
cfg_layout.layout = 'easycapM11.mat';
layout = ft_prepare_layout(cfg_layout);

% Exclude FieldTrip pseudo-channels (COMNT, SCALE)
is_pseudo     = ismember(layout.label, {'COMNT', 'SCALE'});
layout_labels = layout.label(~is_pseudo);
layout_pos    = layout.pos(~is_pseudo, :);

% -------------------------------------------------------------------------
% 2. Separate recording channels from reference/ground electrodes
%
%    CPz (analysis reference, offline re-reference) and AFz (ground/initial
%    reference) are not in the EEG data files but may already appear in the
%    easycapM11 layout.  Keeping them out of fake_tl avoids duplicate-label
%    errors that occur when the layout already contains them.
% -------------------------------------------------------------------------
ref_label = 'CPz';
gnd_label = 'AFz';

is_ref_gnd  = ismember(layout_labels, {ref_label, gnd_label});
rec_labels  = layout_labels(~is_ref_gnd);   % recording channels only
rec_pos     = layout_pos(~is_ref_gnd, :);

% -------------------------------------------------------------------------
% 3. Obtain CPz and AFz positions
%    Prefer positions already in the layout; fall back to midpoint of
%    adjacent electrodes if absent.
% -------------------------------------------------------------------------
% CPz: check layout, else midpoint of Cz and Pz
if any(strcmp(layout_labels, ref_label))
    cpz_pos = layout_pos(strcmp(layout_labels, ref_label), :);
else
    cpz_pos = mean([layout_pos(strcmp(layout_labels, 'Cz'), :); ...
                    layout_pos(strcmp(layout_labels, 'Pz'), :)], 1);
end

% AFz: check layout, else midpoint of Fz and Fpz
if any(strcmp(layout_labels, gnd_label))
    afz_pos = layout_pos(strcmp(layout_labels, gnd_label), :);
else
    afz_pos = mean([layout_pos(strcmp(layout_labels, 'Fz'),  :); ...
                    layout_pos(strcmp(layout_labels, 'Fpz'), :)], 1);
end

% -------------------------------------------------------------------------
% 4. Create fake timelock data
%    Uses only the recording channels — no CPz or AFz — to avoid any
%    duplicate-label issue regardless of the layout file's contents.
% -------------------------------------------------------------------------
n_rec          = numel(rec_labels);
fake_tl        = [];
fake_tl.label  = rec_labels;           % Nx1 cell, recording channels only
fake_tl.avg    = zeros(n_rec, 1);      % [n_chan x 1], all zeros
fake_tl.time   = [0];                  % single time point at 0 ms
fake_tl.dimord = 'chan_time';

% -------------------------------------------------------------------------
% 5. Render head outline via ft_topoplotER
%    Pass layout as a string so FieldTrip uses the original file directly.
%    marker='off' suppresses built-in electrode rendering; circles and
%    labels are drawn manually in step 6.
% -------------------------------------------------------------------------
fig = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [0 0 18 20]);

cfg_topo            = [];
cfg_topo.layout     = 'easycapM11.mat';   % string — not modified struct
cfg_topo.xlim       = [0 0];              % select the single time point
cfg_topo.style      = 'blank';
cfg_topo.comment    = 'no';
cfg_topo.colorbar   = 'no';
cfg_topo.marker     = 'off';

ft_topoplotER(cfg_topo, fake_tl);

% -------------------------------------------------------------------------
% 6. Overlay electrode circles and labels on the ft_topoplotER axes
% -------------------------------------------------------------------------
ax = gca;
hold(ax, 'on');

% Electrode circle radius: 38% of median nearest-neighbour distance
dist_mat  = squareform(pdist(rec_pos));
dist_mat(dist_mat == 0) = Inf;
elec_r    = median(min(dist_mat, [], 2)) * 0.38;
theta_cir = linspace(0, 2*pi, 60);

% Color definitions
col_act_face = [1.00, 1.00, 1.00];   % active channels: white fill
col_act_edge = [0.25, 0.25, 0.25];   % active channels: dark gray edge
col_ref_face = [0.45, 0.70, 0.95];   % reference CPz: light blue fill
col_gnd_face = [0.65, 0.65, 0.65];   % ground AFz: gray fill
col_act_text = [0.00, 0.00, 0.00];   % active channels: black label
col_ref_text = [1.00, 1.00, 1.00];   % reference: white label
col_gnd_text = [0.10, 0.10, 0.10];   % ground: dark label

font_sz = 6.5;   % pt

% Combine all electrodes: recording channels + reference + ground
all_labels = [rec_labels;  {ref_label}; {gnd_label}];
all_pos    = [rec_pos;      cpz_pos;     afz_pos   ];

for i = 1:numel(all_labels)
    lbl = all_labels{i};
    cx  = all_pos(i, 1);
    cy  = all_pos(i, 2);

    if strcmp(lbl, ref_label)
        face_c = col_ref_face;
        text_c = col_ref_text;
    elseif strcmp(lbl, gnd_label)
        face_c = col_gnd_face;
        text_c = col_gnd_text;
    else
        face_c = col_act_face;
        text_c = col_act_text;
    end

    patch(ax, cx + elec_r * cos(theta_cir), cy + elec_r * sin(theta_cir), ...
        face_c, 'EdgeColor', col_act_edge, 'LineWidth', 0.5);

    % Display label: AFz is shown as 'GND' (cap marking), electrode ID unchanged
    disp_lbl = lbl;
    if strcmp(lbl, gnd_label), disp_lbl = 'GND'; end

    text(ax, cx, cy, disp_lbl, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', font_sz, 'FontWeight', 'bold', 'Color', text_c, ...
        'FontName', 'Arial', 'Interpreter', 'none');
end

% -------------------------------------------------------------------------
% 7. Save as SVG
% -------------------------------------------------------------------------
out_dir  = fullfile(prj_dir, 'result', 'fig_electrode_map');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
out_path = fullfile(out_dir, 'electrode_map.svg');

print(fig, '-dsvg', out_path);
close(fig);
fprintf('Saved: %s\n', out_path);
