% userConfig.m
% Returns a struct with all user-tunable parameters and file paths.
% Edit this file to configure the model for your use case.

% === Data file paths ===
config.dataFiles = struct();
config.dataFiles.nodalPrices        = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nodal_prices_filled.csv';
config.dataFiles.hubPrices          = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_hub_prices_filled.csv';
config.dataFiles.nodalGeneration    = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nodal_generation.csv';
config.dataFiles.regup              = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_regup_filled.csv';
config.dataFiles.regdown            = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_regdown_filled.csv';
config.dataFiles.nonspin            = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nonspin_filled.csv';
config.dataFiles.ancillaryForecast  = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/forecasted_annual_ancillary.csv';
config.dataFiles.hourlyHubForecasts = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/hourly_hub_forecasts.csv';
config.dataFiles.hourlyNodalForecasts = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/hourly_nodal_forecasts.csv';

% === Timestamp column names (explicit mapping) ===
config.timestampVars = struct();
config.timestampVars.nodalPrices = 'Timestamp';
config.timestampVars.hubPrices = 'Timestamp';
config.timestampVars.nodalGeneration = 'Timestamp';
config.timestampVars.regup = 'Timestamp';
config.timestampVars.regdown = 'Timestamp';
config.timestampVars.nonspin = 'Timestamp';
config.timestampVars.hourlyHubForecasts = 'Timestamp';
config.timestampVars.hourlyNodalForecasts = 'Timestamp';
% Note: ancillaryForecast is not included here; it is loaded and used separately as an annual target, not as a time series.

% === Output directories ===
config.outputDirs = struct();
config.outputDirs.eda         = 'EDA_Results';
config.outputDirs.correlation = 'Correlation_Results';
config.outputDirs.simulation  = 'Simulation_Results';
config.outputDirs.validation  = 'Validation_Results';

% === Resolution and alignment ===
config.resolution = minutes(5); % Default target resolution (change as needed)

% === Simulation parameters ===
config.simulation = struct();
config.simulation.nPaths = 2; % For faster debugging
config.simulation.length = [];   % Simulation length (leave empty to use data length)
config.simulation.randomSeed = 42;

% === Jump modeling options ===
config.jumpModeling = struct();
config.jumpModeling.detectionMethod = 'std'; % 'std' (use N x rolling/global std) or 'percentile' (use percentile threshold)
config.jumpModeling.threshold = 4.765;           % If 'std', this is the multiplier (e.g., 4 for 4x std). If 'percentile', this is the percentile (e.g., 95)
config.jumpModeling.useEmpiricalDistribution = false; % true: sample jump sizes empirically; false: use fitted normal
config.jumpModeling.regimeConditional = true; % true: use regime-conditional jump frequency/size if available
config.jumpModeling.minJumpSize = 0;         % Minimum absolute jump size to consider (optional, default 0)
config.jumpModeling.info = 'Configure jump detection and simulation: detectionMethod (std/percentile), threshold, empirical/fitted, regimeConditional.';

% === Innovation distribution options (Sprint 2: Heavy-Tailed Innovations) ===
config.innovationDistribution = struct();
config.innovationDistribution.type = 't'; % 'gaussian', 't', or 'custom'
config.innovationDistribution.degreesOfFreedom = 9; % Leave empty to auto-calibrate to match historical kurtosis
config.innovationDistribution.info = 'Configure innovation distribution for simulated returns: type (gaussian/t/custom), degreesOfFreedom (empty=auto)';
config.innovationDistribution.enabled = true; % Enable heavy-tailed innovations
config.innovationDistribution.type = 't'; % Use t-distribution for innovations
config.innovationDistribution.degreesOfFreedom = 8; % Tune as needed (lower = fatter tails)

% === Copula modeling options (Sprint 3: Empirical/Copula Bootstrapping) ===
config.copulaType = 't'; % 'gaussian', 't', or 'vine' for cross-product correlation modeling
config.copulaInfo = 'Configure copula for modeling cross-product correlations: gaussian (simpler), t (fat tails), vine (flexible)';

% === Block bootstrapping options (Sprint 3: Block Bootstrapping) ===
config.blockBootstrapping = struct();
config.blockBootstrapping.enabled = true; % true to use block bootstrapping for returns
config.blockBootstrapping.blockSize = 155;  % Block size in time steps (e.g., 24 for 24-hour blocks)
config.blockBootstrapping.conditional = false; % true to enable conditional block sampling
config.blockBootstrapping.conditionType = 'volatility'; % 'regime' or 'volatility'
config.blockBootstrapping.info = 'Configure block bootstrapping: enabled, blockSize (steps), conditional (by regime/volatility)';

% === Regime-switching volatility modulation options (Sprint 4) ===
config.regimeVolatilityModulation = struct();
config.regimeVolatilityModulation.enabled = true; % true to apply regime-specific volatility modulation
config.regimeVolatilityModulation.amplificationFactor = 1.0; % >1 amplify, <1 dampen, 1=no change
config.regimeVolatilityModulation.maxVolRatio = 100; % Max ratio for volatility scaling
config.regimeVolatilityModulation.info = 'Configure regime volatility modulation: enabled, amplificationFactor (scales regime-specific volatility)';

% === Output/diagnostic options ===
config.savePlots = true;
config.savePatterns = true;
config.saveDiagnostics = true;

% === Regime-switching options ===
config.useRegimeSwitching = true; % Set false to disable regime volatility modulation

% === Time-varying correlation analysis options ===
config.timeVaryingCorr = struct();
config.timeVaryingCorr.minOverlap = 10; % Minimum non-NaN values per product per window (default: 10)
config.timeVaryingCorr.consistencyMode = 'strict'; % 'flexible' (dynamic product inclusion) or 'strict' (all products required)

% === Documentation/help ===
config.info = 'Edit this file to configure all model parameters, file paths, and options.';

% --- Simulation Tuning Parameters (for diagnostics and stylized fact matching) ---
% Block Bootstrapping
config.blockBootstrapping.enabled = true; % Enable block bootstrapping for returns
config.blockBootstrapping.blockSize = 155; % Block size (e.g., 24=1 day, 48=2 days, 168=1 week)
% To experiment, change blockSize to 24, 48, 168, etc. and rerun diagnostics.

% Jumps
config.jumpModeling.enabled = true; % Set true to enable jump injection, false to disable
config.jumpModeling.useEmpiricalDistribution = true; % Use empirical jump size distribution
config.jumpModeling.minJumpSize = 0; % Minimum jump size to consider (set as needed)

% Heavy-Tailed Innovations
config.innovationDistribution.enabled = false; % Set true to enable, false to disable
config.innovationDistribution.type = 't'; % 'gaussian' or 't'
config.innovationDistribution.degreesOfFreedom = 9; % Only used if type is 't'

% Regime-Switching Volatility Modulation
config.regimeVolatilityModulation.enabled = true; % Set true to enable, false to disable
config.regimeVolatilityModulation.amplificationFactor = 0.85745; % Adjust as needed

% --- End of Simulation Tuning Parameters ---

%% SPRINT 6: POST-SIMULATION VALIDATION CONFIGURATION
% Enable/disable specific diagnostics
config.validation.enableReturnDist = true;      % Compare return distributions
config.validation.enableVolClustering = true;   % Compare volatility clustering (ACF)
config.validation.enableJumpAnalysis = true;    % Compare jump frequency/size
config.validation.enableRegimeDurations = true; % Compare regime durations/transitions
config.validation.enableCorrMatrix = true;      % Compare cross-asset correlations

% Automated flagging thresholds
config.validation.stdDeviationThreshold = 0.5;   % Flag if simulated std deviates >50% from historical
config.validation.jumpDeviationThreshold = 0.5;  % Flag if simulated jump freq deviates >50% from historical

% Output directory for validation results
config.validation.outputDir = 'Validation_Results';

% === Regime Detection Parameters ===
config.regimeDetection = struct();
config.regimeDetection.nRegimes = 2; % Number of regimes (set to 2, 3, or 'auto')
config.regimeDetection.method = 'rollingvol'; % Options: 'HMM', 'bayesian', 'rollingVol', etc.
config.regimeDetection.windowSize = 'auto'; % Rolling window size for volatility regime detection (set to integer or 'auto')
config.regimeDetection.threshold = 'auto'; % Threshold for regime detection (set to value or 'auto' for automatic selection)
config.regimeDetection.minDuration = 3; % Minimum duration of regimes in time steps
config.regimeDetection.info = 'Configure regime detection: nRegimes, method (HMM/bayesian/rollingVol), windowSize, threshold, minDuration.';

% === Innovation distribution options (Sprint 2: Heavy-Tailed Innovations) ===
config.innovationDistribution = struct();
config.innovationDistribution.type = 't'; % 'gaussian', 't', or 'custom'
config.innovationDistribution.degreesOfFreedom = 9; % Leave empty to auto-calibrate to match historical kurtosis
config.innovationDistribution.info = 'Configure innovation distribution for simulated returns: type (gaussian/t/custom), degreesOfFreedom (empty=auto)';
config.innovationDistribution.enabled = true; % Enable heavy-tailed innovations

% === Copula modeling options (Sprint 3: Empirical/Copula Bootstrapping) ===
config.copulaType = 't'; % 'gaussian', 't', or 'vine' for cross-product correlation modeling
config.copulaInfo = 'Configure copula for modeling cross-product correlations: gaussian (simpler), t (fat tails), vine (flexible)';

% === Block bootstrapping options (Sprint 3: Block Bootstrapping) ===
config.blockBootstrapping = struct();
config.blockBootstrapping.enabled = true; % true to use block bootstrapping for returns
config.blockBootstrapping.blockSize = 155;  % Block size in time steps (e.g., 24 for 24-hour blocks)
config.blockBootstrapping.conditional = false; % true to enable conditional block sampling
config.blockBootstrapping.conditionType = 'volatility'; % 'regime' or 'volatility'
config.blockBootstrapping.info = 'Configure block bootstrapping: enabled, blockSize (steps), conditional (by regime/volatility)';

% === Regime-switching volatility modulation options (Sprint 4) ===
config.regimeVolatilityModulation = struct();
config.regimeVolatilityModulation.enabled = true; % true to apply regime-specific volatility modulation
config.regimeVolatilityModulation.amplificationFactor = 1.0; % >1 amplify, <1 dampen, 1=no change
config.regimeVolatilityModulation.maxVolRatio = 100; % Max ratio for volatility scaling
config.regimeVolatilityModulation.info = 'Configure regime volatility modulation: enabled, amplificationFactor (scales regime-specific volatility)';

% === Output/diagnostic options ===
config.savePlots = true;
config.savePatterns = true;
config.saveDiagnostics = true;

% === Regime-switching options ===
config.useRegimeSwitching = true; % Set false to disable regime volatility modulation

% === Time-varying correlation analysis options ===
config.timeVaryingCorr = struct();
config.timeVaryingCorr.minOverlap = 10; % Minimum non-NaN values per product per window (default: 10)
config.timeVaryingCorr.consistencyMode = 'strict'; % 'flexible' (dynamic product inclusion) or 'strict' (all products required)

% === Documentation/help ===
config.info = 'Edit this file to configure all model parameters, file paths, and options.';

% --- Simulation Tuning Parameters (for diagnostics and stylized fact matching) ---
% To experiment, change blockSize to 24, 48, 168, etc. and rerun diagnostics.

% Jumps
config.jumpModeling.enabled = true; % Set true to enable jump injection, false to disable
config.jumpModeling.useEmpiricalDistribution = true; % Use empirical jump size distribution

% Heavy-Tailed Innovations
config.innovationDistribution.enabled = false; % Set true to enable, false to disable

% Regime-Switching Volatility Modulation
config.regimeVolatilityModulation.enabled = true; % Set true to enable, false to disable

% --- End of Simulation Tuning Parameters ---

%% SPRINT 6: POST-SIMULATION VALIDATION CONFIGURATION
config.validation = struct();

% Enable/disable specific diagnostics
config.validation.enableReturnDist = true;      % Compare return distributions
config.validation.enableVolClustering = true;   % Compare volatility clustering (ACF)
config.validation.enableJumpAnalysis = true;    % Compare jump frequency/size
config.validation.enableRegimeDurations = true; % Compare regime durations/transitions
config.validation.enableCorrMatrix = true;      % Compare cross-asset correlations

% Automated flagging thresholds
config.validation.stdDeviationThreshold = 0.5;   % Flag if simulated std deviates >50% from historical
config.validation.jumpDeviationThreshold = 0.5;  % Flag if simulated jump freq deviates >50% from historical