% erp_to_freq: convert ERP data to frequency data
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'erp_group_cond'); % set data dir
res_dir = fullfile(prj_dir, 'result', 'freq_group_cond'); % set res dir
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

for gi = 1:length(groups)
    for ci = 1:length(conditions)
        fname = fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat']); % incoude data
        disp('loading...');
        load(fname); % include data

        % wavelet transform
        cfg = [];
        cfg.method      = 'wavelet';
        cfg.output      = 'pow';
        cfg.keeptrials  = 'yes';
        cfg.foi         = logspace(log10(3),log10(90),30);
        cfg.width       = 3 * (cfg.foi / 3) .^ (log(12/3) / log(40/3)); % Minami & Amano (2017): width(f)=3*(f/3)^0.535
        cfg.toi         = round((data.time{1}(1) : 0.05 : data.time{1}(end)) * data.fsample) / data.fsample;
        freq = ft_freqanalysis(cfg, data);

        % baseline correction 
        cfg = [];
        cfg.baseline     = [-0.1 0.0]; 
        cfg.baselinetype = 'db';
        freq = ft_freqbaseline(cfg, freq);

        % save data
        save(fullfile(res_dir, [groups{gi}, '_', conditions{ci}, '.mat']), 'freq', '-v7.3');
    end
end

%% get statistical values
clear;
config;

bands = { ...
    % [1 4],   'Delta',      [0 0.1]; ...
    [4 7],   'Theta',      [0 0.025]; ...
    [7 13],  'alpha',      [0 17*10^-3]; ...
    [13 30], 'beta',      [0 7*10^-3]; ...
    [30 45], 'Low_gamma',  [0 12.5*10^-4]; ...
    [60 90], 'High_gamma', [0 5*10^-6]};

data_dir = fullfile(prj_dir, 'result', 'freq_group_cond'); % set data dir
res_dir = fullfile(prj_dir, 'result', 'freq_group_cond'); % set res dir
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

mx_abs = zeros(1, length(bands));
mx = -inf(1, length(bands));
mn = inf(1, length(bands));
for gi = 1:length(groups)
    for ci = 1:length(conditions)
        disp('loading...');
        load(fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat'])); % include freq

        % for each 50ms
        for t = 0:0.05:0.5
            for bi = 1:length(bands)
                % select data
                cfg = [];
                cfg.latency     = [t-0.001, t+0.001]; % t, around 2ms
                cfg.frequency   = bands{bi, 1};
                freq_t_b = ft_selectdata(cfg, freq);

                % mean over trials
                freq_t_b = ft_freqdescriptives([], freq_t_b);

                mx_abs(bi) = max(mx_abs(bi), max(abs(freq_t_b.powspctrm(:))));
                mx(bi) = max(mx(bi), max(freq_t_b.powspctrm(:)));
                mn(bi) = min(mn(bi), min(freq_t_b.powspctrm(:)));
            end
        end
    end
end

vals = [];
vals.bands = bands;
vals.mx_abs = mx_abs;
vals.mx = mx;
vals.mn = mn;

save(fullfile(res_dir, 'val.mat'), 'vals', '-v7.3');

%% fig - topomap
clear;
config;

data_dir = fullfile(prj_dir, 'result', 'freq_group_cond'); % set data dir
res_dir = fullfile(prj_dir, 'result', 'fig_freq_group_cond_band_topo'); % set res dir
if ~exist(res_dir, 'dir')
    mkdir(res_dir);
end

load(fullfile(data_dir, 'val.mat'));
bands = { ...
    % [1 4],   'Delta',      [0 0.1]; ...
    [4 7],   'Theta',      [0 0.025]; ...
    [7 13],  'alpha',      [0 17*10^-3]; ...
    [13 30], 'beta',      [0 7*10^-3]; ...
    [30 45], 'Low_gamma',  [0 12.5*10^-4]; ...
    [60 90], 'High_gamma', [0 5*10^-6]};

for gi = 1:length(groups)
    for ci = 1:length(conditions)
        disp('loading...');
        load(fullfile(data_dir, [groups{gi}, '_', conditions{ci}, '.mat'])); % include freq

        % for each 50ms
        for t = 0:0.05:0.5
            for bi = 1:length(bands)
                % select data
                cfg = [];
                cfg.latency     = [t-0.001, t+0.001]; % t, around 2ms
                cfg.frequency   = bands{bi, 1};
                freq_t_b = ft_selectdata(cfg, freq);

                % set fig
                fig = figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    
                cfg = [];
                cfg.zlim               = [vals.mn(bi), vals.mx(bi)];
                % cfg.zlim               = [-vals.mx_abs(bi), vals.mx_abs(bi)];
                cfg.colorbar           = 'yes';
                cfg.layout             = 'easycapM11.mat';
                cfg.colormap           = 'jet';
                ft_topoplotTFR(cfg, freq_t_b);
                saveas(fig, fullfile(res_dir, [groups{gi}, '_', conditions{ci}, '_', bands{bi, 2}, '_', num2str(t*1000), '.jpg']));
                close(fig);
            end
        end
    end
end