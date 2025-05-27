function markovModel = fit_regime_markov_model(regimeLabels)
%FIT_REGIME_MARKOV_MODEL Estimate Markov transition matrix and regime durations from regime labels.
%   markovModel = fit_regime_markov_model(regimeLabels)
%   - regimeLabels: vector or table of regime labels (integers)
%   - markovModel: struct with transition matrix, durations, stationary dist

if istable(regimeLabels)
    regimeLabels = table2array(regimeLabels);
end
regimeLabels = regimeLabels(:);
regimeLabels = regimeLabels(~isnan(regimeLabels));
regimes = unique(regimeLabels);
nRegimes = numel(regimes);

% Transition matrix
transMat = zeros(nRegimes);
for i = 1:length(regimeLabels)-1
    from = regimeLabels(i);
    to = regimeLabels(i+1);
    transMat(from, to) = transMat(from, to) + 1;
end
transMat = transMat ./ sum(transMat,2);
transMat(isnan(transMat)) = 0;

% Regime durations
durs = diff(find([1; diff(regimeLabels)~=0; 1]));

% Stationary distribution
[vecs, vals] = eig(transMat');
[~, idx] = min(abs(diag(vals)-1));
statDist = abs(vecs(:,idx)) / sum(abs(vecs(:,idx)));

markovModel = struct('transitionMatrix', transMat, 'regimeDurations', durs, 'stationaryDist', statDist, 'nRegimes', nRegimes);

% Plot durations
figure; histogram(durs, 'BinMethod', 'integers'); title('Regime Durations'); xlabel('Duration'); ylabel('Count');

% Plot transition matrix
figure; imagesc(transMat); colorbar; title('Regime Transition Matrix'); xlabel('To'); ylabel('From');

end

% Unit test
function test_fit_regime_markov_model()
    seq = [ones(1,10), 2*ones(1,5), ones(1,8), 2*ones(1,7)]';
    model = fit_regime_markov_model(seq);
    assert(all(size(model.transitionMatrix) == [2 2]));
    assert(model.nRegimes == 2);
    disp('test_fit_regime_markov_model passed');
end 