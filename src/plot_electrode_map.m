% plot_electrode_map.m
% Generates an SVG electrode diagram for exp1 EEG study.
%
% Rendering approach:
%   ft_topoplotER (style='blank', marker='off') is used to draw the head
%   outline (circle, nose, ears) via the ANT waveguard 64ch layout.
%   Electrode circles and labels are then overlaid on the resulting axes
%   using coordinates extracted from the same layout.
%
% Electrode configuration:
%   - Active channels (n = 63): 10-20 extended system, ANT waveguard 64ch cap
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

% Active EEG channels used in exp1 (63 recording channels + CPz + AFz)
active_channels = { ...
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

% -------------------------------------------------------------------------
% 1. Load ANT waveguard 64ch layout and extract electrode positions.
%    cfg_layout.channel restricts the layout to active channels so that
%    the internal position scaling in ft_prepare_layout uses the same
%    channel subset as ft_topoplotER will use later.
% -------------------------------------------------------------------------
cfg_layout         = [];
cfg_layout.layout  = 'standard_waveguard64_1005_rotated.elc';
cfg_layout.channel = active_channels;
layout = ft_prepare_layout(cfg_layout);

% Remove pseudo-channels (COMNT, SCALE) from the layout struct so they
% are absent from both the manual drawing and the ft_topoplotER call.
is_pseudo = ismember(layout.label, {'COMNT', 'SCALE'});
layout.label  = layout.label(~is_pseudo);
layout.pos    = layout.pos(~is_pseudo, :);
if isfield(layout, 'width'),  layout.width  = layout.width(~is_pseudo);  end
if isfield(layout, 'height'), layout.height = layout.height(~is_pseudo); end

% T9 and T10 sit at the ear level (near/below equator) and would distort
% the position scaling if included in cfg_layout.channel.  Add them
% manually at the inner edge of the ear outline (head circle radius = 0.5).
t9_pos  = [-0.49  0.00];   % left ear
t10_pos = [ 0.49  0.00];   % right ear
layout.label  = [layout.label;  {'T9'; 'T10'}];
layout.pos    = [layout.pos;    t9_pos; t10_pos];
if isfield(layout, 'width')
    layout.width  = [layout.width;  median(layout.width([1 end])); ...
                                    median(layout.width([1 end]))];
end
if isfield(layout, 'height')
    layout.height = [layout.height; median(layout.height([1 end])); ...
                                    median(layout.height([1 end]))];
end

layout_labels = layout.label;
layout_pos    = layout.pos;

% -------------------------------------------------------------------------
% 2. Separate recording channels from reference/ground electrodes
%
%    CPz (analysis reference, offline re-reference) and AFz (ground/initial
%    reference) are not in the EEG data files but appear in the waveguard
%    layout.  Keeping them out of fake_tl avoids duplicate-label errors
%    that occur when the layout already contains them.
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
%    Pass the layout struct (not a string) so ft_topoplotER uses the same
%    pre-scaled positions without recomputing the layout internally.
%    marker='off' suppresses built-in electrode rendering; circles and
%    labels are drawn manually in step 6.
% -------------------------------------------------------------------------
fig = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [0 0 18 20]);

cfg_topo            = [];
cfg_topo.layout     = layout;   % pass struct so ft_topoplotER uses the same pre-scaled positions
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

font_sz = 8;   % pt

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
