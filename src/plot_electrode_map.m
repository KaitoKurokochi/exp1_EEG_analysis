% plot_electrode_map.m
% Generates an SVG electrode diagram for exp1 EEG study.
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
% Load 2D layout
% -------------------------------------------------------------------------
cfg_layout        = [];
cfg_layout.layout = 'easycapM11.mat';
layout = ft_prepare_layout(cfg_layout);

% Remove FieldTrip pseudo-channels (COMNT, SCALE)
valid      = ~ismember(layout.label, {'COMNT', 'SCALE'});
act_labels = layout.label(valid);
act_pos    = layout.pos(valid, :);   % [n x 2], layout coordinate units

% -------------------------------------------------------------------------
% Compute positions for non-recording electrodes
% -------------------------------------------------------------------------
% CPz (analysis reference): midpoint of Cz and Pz along mid-sagittal plane
idx_Cz  = strcmp(act_labels, 'Cz');
idx_Pz  = strcmp(act_labels, 'Pz');
cpz_pos = (act_pos(idx_Cz, :) + act_pos(idx_Pz, :)) / 2;

% AFz (ground): midpoint of Fz and Fpz along mid-sagittal plane
idx_Fz   = strcmp(act_labels, 'Fz');
idx_Fpz  = strcmp(act_labels, 'Fpz');
afz_pos  = (act_pos(idx_Fz, :) + act_pos(idx_Fpz, :)) / 2;

% Combine all electrode data
all_labels = [act_labels;  {'CPz'};  {'AFz'}];
all_pos    = [act_pos;      cpz_pos;  afz_pos];
n_elec     = numel(all_labels);

% -------------------------------------------------------------------------
% Layout geometry
% -------------------------------------------------------------------------
% Electrode circle radius: fraction of the estimated inter-electrode spacing
% Approximate median nearest-neighbour distance as the spacing estimate
n_act = numel(act_labels);
dist_mat = squareform(pdist(act_pos));
dist_mat(dist_mat == 0) = Inf;
min_dists = min(dist_mat, [], 2);
elec_r = median(min_dists) * 0.38;   % 38% of median nearest-neighbour distance

% -------------------------------------------------------------------------
% Figure setup
% -------------------------------------------------------------------------
fig = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [0 0 18 20]);
ax  = axes('Position', [0.03 0.08 0.88 0.88]);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');

% -------------------------------------------------------------------------
% Head outline (from FieldTrip layout: head circle, nose, ears)
% -------------------------------------------------------------------------
if isfield(layout, 'outline')
    for oi = 1:numel(layout.outline)
        xy = layout.outline{oi};
        if ~isempty(xy)
            plot(ax, xy(:,1), xy(:,2), 'k-', 'LineWidth', 1.5);
        end
    end
end

% -------------------------------------------------------------------------
% Color definitions
% -------------------------------------------------------------------------
col_act_face  = [1.00, 1.00, 1.00];   % active channels: white fill
col_act_edge  = [0.25, 0.25, 0.25];   % active channels: dark gray edge
col_ref_face  = [0.10, 0.40, 0.80];   % reference (CPz): blue fill
col_gnd_face  = [0.65, 0.65, 0.65];   % ground (AFz): gray fill
col_act_text  = [0.00, 0.00, 0.00];   % active channels: black text
col_ref_text  = [1.00, 1.00, 1.00];   % reference: white text
col_gnd_text  = [0.10, 0.10, 0.10];   % ground: dark text

font_sz   = 5;                         % pt
theta_cir = linspace(0, 2*pi, 60);

% -------------------------------------------------------------------------
% Draw electrodes
% -------------------------------------------------------------------------
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
% Legend
% -------------------------------------------------------------------------
% Position legend below the head outline
x_lo = min(all_pos(:,1));
x_hi = max(all_pos(:,1));
y_lo = min(all_pos(:,2));

legend_y  = y_lo - 0.13;
legend_xs = [x_lo + 0.05, x_lo + 0.40, x_lo + 0.75];
legend_labels = {'Active channel (n = 63)', 'Reference (CPz)', 'Ground (AFz)'};
legend_faces  = {col_act_face, col_ref_face, col_gnd_face};
legend_texts  = {col_act_text, col_ref_text, col_gnd_text};

for li = 1:3
    patch(ax, legend_xs(li) + elec_r * cos(theta_cir), legend_y + elec_r * sin(theta_cir), ...
        legend_faces{li}, 'EdgeColor', col_act_edge, 'LineWidth', 0.5);
    text(ax, legend_xs(li) + elec_r * 1.6, legend_y, legend_labels{li}, ...
        'VerticalAlignment', 'middle', 'FontSize', 7, 'Color', [0 0 0], ...
        'FontName', 'Arial');
end

% -------------------------------------------------------------------------
% Axis limits
% -------------------------------------------------------------------------
x_margin = 0.10;
y_margin_top = 0.12;
y_margin_bot = 0.20;   % extra space for legend

xlim(ax, [x_lo - x_margin,   x_hi + x_margin]);
ylim(ax, [legend_y - y_margin_bot, max(all_pos(:,2)) + y_margin_top]);

% -------------------------------------------------------------------------
% Save as SVG
% -------------------------------------------------------------------------
out_dir  = fullfile(prj_dir, 'result', 'fig_electrode_map');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
out_path = fullfile(out_dir, 'electrode_map.svg');

print(fig, '-dsvg', out_path);
close(fig);
fprintf('Saved: %s\n', out_path);
