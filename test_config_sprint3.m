% Test configuration for Sprint 3
% test_config_sprint3.m

config = struct();

% Copula configuration
config.copulaType = 't';  % Use t-copula which is more robust

% General config (minimal for testing)
config.simulation = struct();
config.simulation.nPaths = 1000;
config.simulation.randomSeed = 42;
