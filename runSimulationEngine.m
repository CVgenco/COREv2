% runSimulationEngine.m
% Orchestrates Sprint 5: Robust simulation engine with capping, mean reversion, and diagnostics

function runSimulationEngine(configFile)
%RUNSIMULATIONENGINE Run robust simulation engine for Sprint 5.
%   Loads all fitted parameters and copulas, simulates price paths, logs diagnostics, saves results.

run(configFile); % Loads config
load('EDA_Results/returnsTable.mat', 'returnsTable');
load('EDA_Results/paramResults.mat', 'paramResults');
load('EDA_Results/innovationsStruct.mat', 'innovationsStruct');
load('EDA_Results/copulaStruct.mat', 'copulaStruct');
products = fieldnames(returnsTable);
nProducts = numel(products);
% Get number of observations from the first product
firstProduct = products{1};
nObs = length(returnsTable.(firstProduct)) + 1;
nPaths = config.simulation.nPaths;

% Initialize output
simPaths = struct();
regimePaths = struct();
pathDiagnostics = struct();

for i = 1:nProducts
    pname = products{i};
    simPaths.(pname) = nan(nObs, nPaths);
    regimePaths.(pname) = nan(nObs-1, nPaths);
    pathDiagnostics.(pname) = struct('cappedReturns', zeros(nObs-1, nPaths), ...
                                     'cappedJumps', zeros(nObs-1, nPaths), ...
                                     'cappedPrices', zeros(nObs, nPaths), ...
                                     'returns', nan(nObs-1, nPaths), ...
                                     'prices', nan(nObs, nPaths), ...
                                     'jumps', zeros(nObs-1, nPaths));
end

rng(config.simulation.randomSeed);
maxCaps = 100; % Max allowed capping events per path before flagging

for p = 1:nPaths
    cappedPathFlag = false;
    cappedCount = zeros(1, nProducts);
    % For each product, initialize price and regime
    for i = 1:nProducts
        pname = products{i};
        % Initial price: use a baseline value since we're working with returns
        simPaths.(pname)(1,p) = 100 + randn*1e-6; % Start from baseline price
        % Initial regime: sample from stationary distribution
        markovModel = paramResults.(pname).markovModel;
        regimeSeq = zeros(nObs-1,1);
        regimeSeq(1) = randsample(1:markovModel.nRegimes,1,true,markovModel.stationaryDist);
        % Simulate regime sequence
        for t = 2:nObs-1
            prevReg = regimeSeq(t-1);
            regimeSeq(t) = randsample(1:markovModel.nRegimes,1,true,markovModel.transitionMatrix(prevReg,:));
        end
        regimePaths.(pname)(:,p) = regimeSeq;
    end
    % Simulate returns and prices
    for t = 1:nObs-1
        currRegimes = zeros(1,nProducts);
        for i = 1:nProducts
            pname = products{i};
            currRegimes(i) = regimePaths.(pname)(t,p);
        end
        regimeIdx = mode(currRegimes);
        copula = copulaStruct(regimeIdx);
        % Generate copula sample
        if strcmpi(copula.type, 't')
            if isfield(copula, 'df')
                % Ensure df is a positive integer for mvtrnd
                df_int = round(max(1, copula.df));
                u = copularnd('t', copula.params, 1, df_int);
            else
                error('Copula struct for type "t" is missing the required field "df" (degrees of freedom).');
            end
        else
            u = copularnd(copula.type, copula.params, 1);
        end
        innovs = zeros(1,nProducts);
        for i = 1:nProducts
            pname = products{i};
            empInnovs = innovationsStruct.(pname)(currRegimes(i)).innovations;
            empInnovs = empInnovs(~isnan(empInnovs));
            if isempty(empInnovs)
                innovs(i) = 0;
            else
                innovs(i) = quantile(empInnovs, u(i));
            end
        end
        for i = 1:nProducts
            pname = products{i};
            currReg = currRegimes(i);
            garchModel = paramResults.(pname).garchModels(currReg).model;
            prevReturns = diff(simPaths.(pname)(max(1,t-10):t,p));
            if isempty(prevReturns), prevReturns = 0; end
            try
                % Try using the custom_infer function if available
                if exist('custom_infer', 'file')
                    [~,V] = custom_infer(garchModel, prevReturns);
                    condVol = sqrt(V(end));
                else
                    % Fallback: use standardized residual approach
                    condVol = std(prevReturns, 'omitnan');
                    if isnan(condVol) || condVol==0, condVol = 1; end
                end
            catch
                condVol = std(prevReturns, 'omitnan');
                if isnan(condVol) || condVol==0, condVol = 1; end
            end
            ret = condVol * innovs(i);
            % 1. Capping returns
            returnsData = returnsTable.(pname);
            if ~isempty(returnsData) && ~all(isnan(returnsData))
                capRet = 3 * std(returnsData, 'omitnan');
                if abs(ret) > capRet
                    ret = sign(ret) * capRet;
                    pathDiagnostics.(pname).cappedReturns(t,p) = 1;
                    cappedCount(i) = cappedCount(i) + 1;
                end
            end
            % 2. Add jump if needed, with capping
            jumpModel = paramResults.(pname).jumpModels(currReg);
            jump = 0;
            if rand < jumpModel.jumpFreq && ~isempty(jumpModel.jumpSizes)
                jump = jumpModel.jumpSizes(randi(numel(jumpModel.jumpSizes)));
                capJump = 3 * std(jumpModel.jumpSizes, 'omitnan');
                if abs(jump) > capJump
                    jump = sign(jump) * capJump;
                    pathDiagnostics.(pname).cappedJumps(t,p) = 1;
                    cappedCount(i) = cappedCount(i) + 1;
                end
                ret = ret + jump;
                pathDiagnostics.(pname).jumps(t,p) = jump;
            end
            % 3. Mean reversion (auto-calibrated)
            returnsData = returnsTable.(pname);
            if ~isempty(returnsData) && ~all(isnan(returnsData))
                anchor = mean(returnsData, 'omitnan');
                stdev = std(returnsData, 'omitnan');
                if stdev > 0
                    anchorWeight = min(0.5, 0.1 + 0.4 * (abs(simPaths.(pname)(t,p) - anchor) / (5*stdev)));
                    ret = ret + anchorWeight * (anchor - simPaths.(pname)(t,p));
                end
            end
            % 4. Update price and cap price
            simPaths.(pname)(t+1,p) = simPaths.(pname)(t,p) + ret;
            returnsData = returnsTable.(pname);
            if ~isempty(returnsData) && ~all(isnan(returnsData))
                anchor = mean(returnsData, 'omitnan');
                stdev = std(returnsData, 'omitnan');
                if stdev > 0
                    capPrice = anchor + 5 * stdev;
                    minPrice = anchor - 5 * stdev;
                    if simPaths.(pname)(t+1,p) > capPrice
                        simPaths.(pname)(t+1,p) = capPrice;
                        pathDiagnostics.(pname).cappedPrices(t+1,p) = 1;
                        cappedCount(i) = cappedCount(i) + 1;
                    elseif simPaths.(pname)(t+1,p) < minPrice
                        simPaths.(pname)(t+1,p) = minPrice;
                        pathDiagnostics.(pname).cappedPrices(t+1,p) = 1;
                        cappedCount(i) = cappedCount(i) + 1;
                    end
                end
            end
            % 5. Log diagnostics
            pathDiagnostics.(pname).returns(t,p) = ret;
            pathDiagnostics.(pname).prices(t+1,p) = simPaths.(pname)(t+1,p);
        end
        % Error handling: flag path if too many cappings
        if any(cappedCount > maxCaps)
            cappedPathFlag = true;
            warning('Path %d: Too many capping events for one or more products. Path flagged for review.', p);
            break;
        end
    end
end

% Save results
if ~exist('Simulation_Results', 'dir'), mkdir('Simulation_Results'); end
save('Simulation_Results/simPaths.mat', 'simPaths');
save('Simulation_Results/regimePaths.mat', 'regimePaths');
save('Simulation_Results/pathDiagnostics.mat', 'pathDiagnostics');

% Plot sample paths and diagnostics
for i = 1:nProducts
    pname = products{i};
    figure; plot(simPaths.(pname)); title(['Simulated Paths: ' pname]); xlabel('Time'); ylabel('Price');
    saveas(gcf, sprintf('Simulation_Results/simPaths_%s.png', pname)); close;
    figure; imagesc(pathDiagnostics.(pname).cappedPrices); colorbar;
    title(['Capped Prices: ' pname]); xlabel('Path'); ylabel('Time');
    saveas(gcf, sprintf('Simulation_Results/cappedPrices_%s.png', pname)); close;
end

fprintf('Sprint 5 complete: Robust simulation with capping, mean reversion, and diagnostics saved to Simulation_Results.\n');
end