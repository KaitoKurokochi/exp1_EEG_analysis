% plot_electrode_map.m
% Generates an SVG electrode diagram for exp1 EEG study.
%
% Rendering approach:
%   ft_topoplotER (style='blank', marker='off') is used to draw the head
%   outline (circle, nose, ears) based on the easycapM11 layout.
%   Electrode circles and labels are then overlaid on the resulting axes
%   using the layout coordinate system.
%
% Electrode configuration:
%   - Active channels (n = 63): easycapM11 layout (10-20 extended system)
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
% 1. Build extended layout: easycapM11 (63 ch) + CPz (ref) + AFz (gnd)
% -------------------------------------------------------------------------
cfg_layout        = [];
cfg_layout.layout = 'easycapM11.mat';
layout = ft_prepare_layout(cfg_layout);

% Separate active channels from FieldTrip pseudo-channels (COMNT, SCALE)
is_pseudo  = ismember(layout.label, {'COMNT', 'SCALE'});
act_labels = layout.label(~is_pseudo);
act_pos    = layout.pos(~is_pseudo, :);   % [63 x 2] layout coordinate units

% CPz (analysis reference): midpoint of Cz and Pz along mid-sagittal plane
cpz_pos = mean([act_pos(strcmp(act_labels, 'Cz'),  :); ...
                act_pos(strcmp(act_labels, 'Pz'),  :)], 1);

% AFz (ground): midpoint of Fz and Fpz along mid-sagittal plane
afz_pos = mean([act_pos(strcmp(act_labels, 'Fz'),  :); ...
                act_pos(strcmp(act_labels, 'Fpz'), :)], 1);

mean_w = mean(layout.width(~is_pseudo));
mean_h = mean(layout.height(~is_pseudo));

% Extended layout struct (FieldTrip requires COMNT/SCALE to remain present)
ext_layout        = layout;
ext_layout.label  = [act_labels; {'CPz'}; {'AFz'}; layout.label(is_pseudo)];
ext_layout.pos    = [act_pos;     cpz_pos; afz_pos; layout.pos(is_pseudo,:)];
ext_layout.width  = [layout.width(~is_pseudo);  mean_w; mean_w; layout.width(is_pseudo)];
ext_layout.height = [layout.height(~is_pseudo); mean_h; mean_h; layout.height(is_pseudo)];

% -------------------------------------------------------------------------
% 2. Create fake timelock data (all channels, single time point, zeros)
%    Required by ft_topoplotER even when style='blank'
% -------------------------------------------------------------------------
data_labels  = [act_labels; {'CPz'}; {'AFz'}];
n_data_chans = numel(data_labels);

fake_tl          = [];
fake_tl.label    = data_labels;
fake_tl.avg      = zeros(n_data_chans, 1);   % [n_chan x 1]
fake_tl.time     = [0];                       % single time point at 0 ms
fake_tl.dimord   = 'chan_time';

% -------------------------------------------------------------------------
% 3. Render head outline via ft_topoplotER
%    style = 'blank' : no topographic color fill
%    marker = 'off'  : suppress built-in electrode markers
%    All electrode circles and labels are drawn manually in step 4.
% -------------------------------------------------------------------------
fig = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [0 0 18 20]);

cfg_topo            = [];
cfg_topo.layout     = ext_layout;
cfg_topo.xlim       = [0 0];      % select the single time point
cfg_topo.style      = 'blank';
cfg_topo.comment    = 'no';
cfg_topo.colorbar   = 'no';
cfg_topo.marker     = 'off';      % electrode markers drawn manually below

ft_topoplotER(cfg_topo, fake_tl);

% -------------------------------------------------------------------------
% 4. Overlay electrode circles and labels on the ft_topoplotER axes
% -------------------------------------------------------------------------
ax = gca;
hold(ax, 'on');

% Electrode circle radius: 38% of median nearest-neighbour distance
dist_mat  = squareform(pdist(act_pos));
dist_mat(dist_mat == 0) = Inf;
elec_r    = median(min(dist_mat, [], 2)) * 0.38;
theta_cir = linspace(0, 2*pi, 60);

% Color definitions
col_act_face = [1.00, 1.00, 1.00];   % active: white fill
col_act_edge = [0.25, 0.25, 0.25];   % active: dark gray edge
col_ref_face = [0.10, 0.40, 0.80];   % reference CPz: blue fill
col_gnd_face = [0.65, 0.65, 0.65];   % ground AFz: gray fill
col_act_text = [0.00, 0.00, 0.00];   % active: black label
col_ref_text = [1.00, 1.00, 1.00];   % reference: white label
col_gnd_text = [0.10, 0.10, 0.10];   % ground: dark label

font_sz = 5;   % pt

% Combine all electrode positions for drawing
all_labels = [act_labels; {'CPz'}; {'AFz'}];
all_pos    = [act_pos;     cpz_pos; afz_pos];
n_elec     = numel(all_labels);

for i = 1:n_elec
    lbl = all_labels{i};
    cx  = all_pos(i, 1);
    cy  = all_pos(i, 2);

    if strcmp(lbl, 'CPz')
        face_c = col_ref_face;
        text_c = col_ref_text;
    elseif strcmp(lbl, 'AFz')
        face_c = col_gnd_face;
        text_c = col_gnd_text;
    else
        face_c = col_act_face;
        text_c = col_act_text;
    end

    patch(ax, cx + elec_r * cos(theta_cir), cy + elec_r * sin(theta_cir), ...
        face_c, 'EdgeColor', col_act_edge, 'LineWidth', 0.5);

    text(ax, cx, cy, lbl, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', font_sz, 'Color', text_c, 'FontName', 'Arial', ...
        'Interpreter', 'none');
end

% -------------------------------------------------------------------------
% 5. Legend (horizontal row below the head outline)
%    Each item: filled circle on the left + description text on the right
% -------------------------------------------------------------------------
% Extend y-axis downward to create space for the legend
ax_xlim  = get(ax, 'XLim');
ax_ylim  = get(ax, 'YLim');
leg_gap  = elec_r * 4.0;               % gap between head bottom and legend
leg_row_h = elec_r * 3.0;             % row height for the legend
leg_y    = ax_ylim(1) - leg_gap;      % y-centre of legend row

ylim(ax, [leg_y - leg_row_h, ax_ylim(2)]);   % extend downward

% Distribute three items evenly across x-axis
x_lo   = ax_xlim(1);
x_rng  = diff(ax_xlim);
leg_xs = x_lo + x_rng * [0.08, 0.42, 0.72];   % left edges of each item

legend_items = { ...
    'Active channel (n = 63)', col_act_face, col_act_edge, col_act_text; ...
    'Reference: CPz',          col_ref_face, col_act_edge, col_ref_text; ...
    'Ground: AFz',             col_gnd_face, col_act_edge, col_gnd_text  ...
};

for li = 1:3
    face_c = legend_items{li, 2};
    edge_c = legend_items{li, 3};
    lx = leg_xs(li);
    % Circle symbol
    patch(ax, lx + elec_r*cos(theta_cir), leg_y + elec_r*sin(theta_cir), ...
        face_c, 'EdgeColor', edge_c, 'LineWidth', 0.5);
    % Description text to the right of the circle
    text(ax, lx + elec_r * 1.5, leg_y, legend_items{li, 1}, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontSize', 6.5, 'Color', [0 0 0], 'FontName', 'Arial');
end

% -------------------------------------------------------------------------
% 6. Save as SVG
% -------------------------------------------------------------------------
out_dir  = fullfile(prj_dir, 'result', 'fig_electrode_map');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
out_path = fullfile(out_dir, 'electrode_map.svg');

print(fig, '-dsvg', out_path);
close(fig);
fprintf('Saved: %s\n', out_path);
