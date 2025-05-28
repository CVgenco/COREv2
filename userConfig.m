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
config.simulation.nPaths = 5; % Increased from 2 for more stability
config.simulation.length = [];   % Simulation length (leave empty to use data length)
config.simulation.randomSeed = 42;

% === Jump modeling options ===
config.jumpModeling = struct();
config.jumpModeling.detectionMethod = 'std'; % 'std' (use N x rolling/global std) or 'percentile' (use percentile threshold)
config.jumpModeling.threshold = 0.1199;           % If 'std', this is the multiplier (e.g., 4 for 4x std). If 'percentile', this is the percentile (e.g., 95)
config.jumpModeling.useEmpiricalDistribution = false; % true: sample jump sizes empirically; false: use fitted normal
config.jumpModeling.regimeConditional = true; % true: use regime-conditional jump frequency/size if available
config.jumpModeling.minJumpSize = 0;         % Minimum absolute jump size to consider (optional, default 0)
config.jumpModeling.info = 'Configure jump detection and simulation: detectionMethod (std/percentile), threshold, empirical/fitted, regimeConditional.';
config.jumpModeling.enabled = true; % Set true to enable jump injection, false to disable

% === Innovation distribution options (Sprint 2: Heavy-Tailed Innovations) ===
config.innovationDistribution = struct();
config.innovationDistribution.type = 't'; % 'gaussian', 't', or 'custom'
config.innovationDistribution.degreesOfFreedom = 7; % Leave empty to auto-calibrate to match historical kurtosis
config.innovationDistribution.info = 'Configure innovation distribution for simulated returns: type (gaussian/t/custom), degreesOfFreedom (empty=auto)';
config.innovationDistribution.enabled = true; % Enable heavy-tailed innovations % This was true, then set to false, then true again. Keeping true.

% === Copula modeling options (Sprint 3: Empirical/Copula Bootstrapping) ===
config.copulaType = 't'; % 'gaussian', 't', or 'vine' for cross-product correlation modeling
config.copulaInfo = 'Configure copula for modeling cross-product correlations: gaussian (simpler), t (fat tails), vine (flexible)';

% === Block bootstrapping options (Sprint 3: Block Bootstrapping) ===
config.blockBootstrapping = struct();
config.blockBootstrapping.enabled = true; % true to use block bootstrapping for returns
config.blockBootstrapping.blockSize = 134;  % Block size in time steps (e.g., 24 for 24-hour blocks)
config.blockBootstrapping.conditional = false; % true to enable conditional block sampling
config.blockBootstrapping.conditionType = 'volatility'; % 'regime' or 'volatility'
config.blockBootstrapping.info = 'Configure block bootstrapping: enabled, blockSize (steps), conditional (by regime/volatility)';

% === Regime-switching volatility modulation options (Sprint 4) ===
config.regimeVolatilityModulation = struct();
config.regimeVolatilityModulation.enabled = true; % true to apply regime-specific volatility modulation
config.regimeVolatilityModulation.amplificationFactor = 0.7317; % >1 amplify, <1 dampen, 1=no change
config.regimeVolatilityModulation.maxVolRatio = 5; % Conservative max ratio for volatility scaling to prevent explosions
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
% Block Bootstrapping: blockSize was 134.
% Jumps: useEmpiricalDistribution was true. minJumpSize was 0.
% Heavy-Tailed Innovations: enabled was false. degreesOfFreedom was 7.
% Regime-Switching Volatility Modulation: amplificationFactor was 0.7317.
% Note: The specific values for tuning parameters like blockSize, jump settings, etc.,
% are now primarily controlled by the Bayesian optimization variables if an optimization is running.
% The values here serve as defaults if not overridden.

% === Regime Detection Parameters ===
config.regimeDetection = struct();
config.regimeDetection.nRegimes = 2; % Number of regimes (set to 2, 3, or 'auto')
config.regimeDetection.method = 'rollingvol'; % Options: 'HMM', 'bayesian', 'rollingVol', etc.
config.regimeDetection.windowSize = 'auto'; % Rolling window size for volatility regime detection (set to integer or 'auto')
config.regimeDetection.threshold = 'auto'; % Threshold for regime detection (set to value or 'auto' for automatic selection)
config.regimeDetection.minDuration = 3; % Minimum duration of regimes in time steps
config.regimeDetection.info = 'Configure regime detection: nRegimes, method (HMM/bayesian/rollingVol), windowSize, threshold, minDuration.';

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

% === Enhanced Data Preprocessing Configuration ===
config.dataPreprocessing = struct();
config.dataPreprocessing.enabled = true; % Enable enhanced data preprocessing with robust outlier detection
config.dataPreprocessing.robustOutlierDetection = true; % Use multi-method robust outlier detection
config.dataPreprocessing.volatilityExplosionPrevention = true; % Enable volatility explosion prevention
config.dataPreprocessing.adaptiveBlockSize = true; % Use adaptive block size optimization

% Robust outlier detection options
config.outlierDetection = struct();
config.outlierDetection.enableIQR = true; % Enable IQR-based outlier detection
config.outlierDetection.enableModifiedZScore = true; % Enable Modified Z-score outlier detection
config.outlierDetection.enableEnergyThresholds = true; % Enable energy market specific thresholds
config.outlierDetection.iqrMultiplier = 2.5; % IQR multiplier (conservative for energy markets)
config.outlierDetection.modifiedZThreshold = 3.5; % Modified Z-score threshold
config.outlierDetection.replacementMethod = 'interpolation'; % 'interpolation', 'median', 'capping', 'winsorizing'
config.outlierDetection.verbose = true; % Enable verbose outlier detection reporting
config.outlierDetection.energyProductBounds = struct(...
    'hub', struct('min', -1000, 'max', 3000), ...
    'regup', struct('min', 0, 'max', 500), ...
    'regdown', struct('min', 0, 'max', 500), ...
    'nonspin', struct('min', 0, 'max', 300), ...
    'nodal', struct('min', -500, 'max', 2000) ...
);

% Missing data handling configuration
config.missingDataHandling = struct();
config.missingDataHandling.enabled = true;
config.missingDataHandling.method = 'adaptive';
config.missingDataHandling.maxGapSize = 24;  % Maximum gap size to interpolate
config.missingDataHandling.verbose = true;

% Volatility control configuration
config.volatilityControl = struct();
config.volatilityControl.enabled = true;
config.volatilityControl.maxVolatilityRatio = 50;  % Maximum allowed volatility ratio
config.volatilityControl.smoothingWindow = 12;    % Hours for volatility smoothing
config.volatilityControl.verbose = true;

% Data quality validation
config.qualityValidation = struct();
config.qualityValidation.enabled = true;
config.qualityValidation.maxMissingPercentage = 20;
config.qualityValidation.minDataPoints = 100;
config.qualityValidation.verbose = true;

% Block size optimization
config.blockSizeOptimization = struct();
config.blockSizeOptimization.enabled = true;
config.blockSizeOptimization.minBlockSize = 12;
config.blockSizeOptimization.maxBlockSize = 168;  % 1 week
config.blockSizeOptimization.evaluationMethod = 'stability';
config.blockSizeOptimization.verbose = true;

% Volatility explosion prevention
config.volatilityPrevention = struct();
config.volatilityPrevention.enabled = true; % Enable volatility explosion prevention
config.volatilityPrevention.maxVolatilityRatio = 5.0; % Maximum volatility ratio threshold
config.volatilityPrevention.rollingWindow = 24; % Rolling window for volatility monitoring
config.volatilityPrevention.earlyWarningMultiplier = 3.0; % Early warning threshold multiplier

% === Bayesian Optimization Safety Configuration ===
config.bayesianOptSafety = struct();
config.bayesianOptSafety.enabled = true; % Enable safety validation before optimization
config.bayesianOptSafety.dataIntegrityChecks = true; % Perform data integrity checks
config.bayesianOptSafety.parameterBoundsValidation = true; % Validate and adjust parameter bounds
config.bayesianOptSafety.volatilityExplosionPrevention = true; % Configure volatility explosion prevention
config.bayesianOptSafety.blockSizeSafetyValidation = true; % Validate block size safety

% --- Enhanced Volatility Controls for Bayesian Optimization ---
config.volatilityControl = struct();
config.volatilityControl.enabled = true;
config.volatilityControl.maxVolatilityRatio = 50;  % Maximum allowed volatility ratio
config.volatilityControl.smoothingWindow = 12;    % Hours for volatility smoothing
config.volatilityControl.maxAllowedStd = 3.0; % Reduce from 5.0 to 3.0 std for hard resets
config.volatilityControl.emergencyDampening = 0.5; % Emergency volatility dampening factor
config.volatilityControl.maxConsecutiveResets = 3; % Max consecutive resets before aborting simulation
config.volatilityControl.verbose = true;