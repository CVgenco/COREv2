# Energy Price & Risk Simulator: Modular Monte Carlo Engine

## Overview
This project implements a robust, modular, and extensible Monte Carlo simulation engine for energy price forecasting in MATLAB. It supports regime-switching, GARCH/EGARCH, jumps, copula-based innovations, and cross-asset dependencies, with automated diagnostics and validation.

---

## Directory Structure
- **Configuration**
  - `userConfig.m` — All configuration options (fully documented)
- **Data Preparation & EDA**
  - `runEDAandPatternExtraction.m` — Data cleaning, alignment, regime detection
  - `data_cleaning.m`, `alignAndSynchronizeProducts.m`, `calculate_returns.m`, `detect_regimes.m`, `identifyVolatilityRegimes.m`, `loadAndInventoryAllProducts.m`, `extract_empirical_innovations.m`, `extractVolatilityAndJumps.m`, `extractHolidayPattern.m`, `extractHourlyPattern.m`, `extractMonthlyPattern.m`, `extractSeasonalBehaviorPattern.m`, `parseVariableResolutionData.m`
- **Parameter Estimation & Modeling**
  - `runParameterEstimation.m` — Automated parameter estimation for regimes, GARCH, jumps
  - `fit_garch_per_regime.m`, `fit_jumps_per_regime.m`, `fit_regime_markov_model.m`, `fit_copula_per_regime.m`, `buildRegimeDependentCorrelations.m`, `buildComprehensiveCorrelationMatrix.m`, `buildTimeVaryingCorrelations.m`, `buildMultiResolutionCorrelations.m`, `calculateCorrelationWithPairwiseDeletion.m`, `determineAdaptiveCorrelationWindow.m`
- **Simulation Engine**
  - `runSimulationAndScenarioGeneration.m`, `runSimulationEngine.m`, `applyBayesianRegimeSwitchingVolatility.m`, `combineDatasetsByResolution.m`, `updateUserConfig.m`
- **Diagnostics & Validation**
  - `runPostSimulationValidation.m`, `runOutputAndValidation.m`, `computeErrorScore.m`, `analyzeRawBootstrappedACF.m`
- **Correlation Analysis**
  - `runCorrelationAnalysis.m`, `check_correlation.py`
- **Modularity & Extensibility**
  - `runModularityAndExtensibilityReport.m` — Checks for modularity, documentation, and test coverage
- **Testing**
  - `tests/` — Unit and integration tests for all modules (see below)
- **Documentation**
  - `README.md`, `CORE _ Documentation.html` (detailed documentation)
- **Output/Results (excluded from Git)**
  - `EDA_Results/`, `Simulation_Results/`, `Validation_Results/`, `BayesOpt_Results/`, `Correlation_Results/`

---

## Sprint-to-Module Mapping
| Sprint | Purpose | Main Scripts/Modules |
|--------|---------|---------------------|
| 1 | Data Preparation & Regime Detection | `runEDAandPatternExtraction.m`, `data_cleaning.m`, ... |
| 2 | Automated Parameter Estimation | `runParameterEstimation.m`, `fit_garch_per_regime.m`, ... |
| 3 | Copula/Innovation Bootstrapping | `runEmpiricalCopulaBootstrapping.m`, `fit_copula_per_regime.m` |
| 4 | Simulation Engine | `runSimulationAndScenarioGeneration.m`, `runSimulationEngine.m` |
| 5 | Robustness & Diagnostics | `runOutputAndValidation.m`, `analyzeRawBootstrappedACF.m` |
| 6 | Post-Simulation Validation | `runPostSimulationValidation.m` |
| 7 | Modularity, Extensibility, Docs | `runModularityAndExtensibilityReport.m`, `README.md` |

---

## Usage
1. **Configure your run:** Edit `userConfig.m` to set file paths, products, and modeling options.
2. **Run EDA and regime detection:**
   ```matlab
   runEDAandPatternExtraction('userConfig.m');
   ```
3. **Parameter estimation:**
   ```matlab
   runParameterEstimation('userConfig.m');
   ```
4. **Copula/innovation extraction:**
   ```matlab
   runEmpiricalCopulaBootstrapping('userConfig.m');
   ```
5. **Simulation:**
   ```matlab
   runSimulationAndScenarioGeneration('userConfig.m', 'Simulation_Results/');
   ```
6. **Validation:**
   ```matlab
   runPostSimulationValidation('userConfig.m');
   ```
7. **Modularity & Extensibility Check:**
   ```matlab
   runModularityAndExtensibilityReport();
   ```

---

## Adding a New Product, Regime, or Model Component
- Add the product's CSV to the data directory.
- Update `userConfig.m` with the new file path and timestamp variable.
- Rerun all modules from EDA onward.
- To add a new regime or model component, extend the relevant function (e.g., `fit_garch_per_regime.m`) and document the option in `userConfig.m`.

---

## Running All Tests
Run all unit and integration tests:
```matlab
cd tests
run test_regime_detection
run test_garch_fitting
run test_jump_detection
run test_copula_fitting
run test_simulation_engine
run test_post_sim_validation
```
All tests save diagnostic plots to `tests/diagnostics/`.

---

## Extensibility & Best Practices
- All modules are self-contained and documented with docstrings.
- No code duplication: shared logic is in utility functions.
- All configuration is in `userConfig.m`.
- Add new products, regimes, or model components by extending the relevant function and updating the config.
- Diagnostics and validation are automated after each sprint/module.
- All output/result directories are excluded from Git via `.gitignore`.

---

## Documentation
- All functions include docstrings describing inputs, outputs, and usage.
- See `userConfig.m` for configuration documentation.
- See `CORE _ Documentation.html` for additional details and advanced usage.

---

## Notes
- **.gitignore**: The repository includes a `.gitignore` that excludes large data, output/results, and OS/editor files.
- **Output directories** (`EDA_Results/`, `Simulation_Results/`, etc.) are not tracked in Git and are generated by running the pipeline.
- **Test coverage**: All new features must be covered by at least one test or validation plot.
- **For further help**, see the documentation files or contact the project maintainer.
