#!/usr/bin/env octave
% Simple test for the copula size fix logic

% Simulate the problematic scenario
products = {'product1', 'product2', 'product3'};
innovations1 = randn(1000, 1);  % Product 1 regime 1
innovations2 = randn(900, 1);   % Product 2 regime 1  
innovations3 = randn(1100, 1);  % Product 3 regime 1

% Test the min length logic
minLength = inf;
lengths = [length(innovations1), length(innovations2), length(innovations3)];
for i = 1:length(lengths)
    minLength = min(minLength, lengths(i));
end

fprintf('Innovation vector lengths: [%d, %d, %d]\n', lengths(1), lengths(2), lengths(3));
fprintf('Minimum length: %d\n', minLength);

% Test matrix building
innovMat = zeros(minLength, length(products));
innovMat(:,1) = innovations1(1:minLength);
innovMat(:,2) = innovations2(1:minLength);
innovMat(:,3) = innovations3(1:minLength);

fprintf('Innovation matrix size: %dx%d\n', size(innovMat));
fprintf('✓ Matrix building successful - no size mismatch!\n');
