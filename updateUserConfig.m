function updateUserConfig(blockSize, df, jumpThreshold, regimeAmpFactor)
% updateUserConfig Updates userConfig.m with new parameters
%   blockSize: integer
%   df: integer
%   jumpThreshold: real
%   regimeAmpFactor: real

configFile = 'userConfig.m';
txt = fileread(configFile);

% === Block Size ===
if contains(txt, 'config.blockBootstrapping.blockSize')
    txt = regexprep(txt, 'config\.blockBootstrapping\.blockSize\s*=\s*\d+;', ...
        sprintf('config.blockBootstrapping.blockSize = %d;', blockSize));
else
    txt = [txt, sprintf('\nconfig.blockBootstrapping.blockSize = %d;\n', blockSize)];
end

% === Degrees of Freedom ===
if contains(txt, 'config.innovationDistribution.degreesOfFreedom')
    txt = regexprep(txt, 'config\.innovationDistribution\.degreesOfFreedom\s*=\s*\d+;', ...
        sprintf('config.innovationDistribution.degreesOfFreedom = %d;', df));
else
    txt = [txt, sprintf('\nconfig.innovationDistribution.degreesOfFreedom = %d;\n', df)];
end

% === Jump Modeling ===
% Enable jump modeling if jumpThreshold is being tuned
txt = regexprep(txt, 'config\.jumpModeling\.enabled\s*=\s*(true|false);', ...
    'config.jumpModeling.enabled = true;');
if ~contains(txt, 'config.jumpModeling.enabled') % Add if not present
    txt = [txt, sprintf('\nconfig.jumpModeling.enabled = true;\n')];
end

% Update jump threshold (assuming detectionMethod is 'std')
if contains(txt, 'config.jumpModeling.threshold')
    txt = regexprep(txt, 'config\.jumpModeling\.threshold\s*=\s*[\d\.]+;', ...
        sprintf('config.jumpModeling.threshold = %.4f;', jumpThreshold));
else
    txt = [txt, sprintf('\nconfig.jumpModeling.threshold = %.4f;\n', jumpThreshold)];
end
% Ensure detection method is 'std' for this threshold to make sense
txt = regexprep(txt, 'config\.jumpModeling\.detectionMethod\s*=\s*''\w+'';', ...
    'config.jumpModeling.detectionMethod = ''std'';');


% === Regime Volatility Modulation ===
% Enable regime modulation if regimeAmpFactor is being tuned
txt = regexprep(txt, 'config\.regimeVolatilityModulation\.enabled\s*=\s*(true|false);', ...
    'config.regimeVolatilityModulation.enabled = true;');
if ~contains(txt, 'config.regimeVolatilityModulation.enabled') % Add if not present
    txt = [txt, sprintf('\nconfig.regimeVolatilityModulation.enabled = true;\n')];
end

% Update amplification factor
if contains(txt, 'config.regimeVolatilityModulation.amplificationFactor')
    txt = regexprep(txt, 'config\.regimeVolatilityModulation\.amplificationFactor\s*=\s*[\d\.]+;', ...
        sprintf('config.regimeVolatilityModulation.amplificationFactor = %.4f;', regimeAmpFactor));
else
    txt = [txt, sprintf('\nconfig.regimeVolatilityModulation.amplificationFactor = %.4f;\n', regimeAmpFactor)];
end

fid = fopen(configFile, 'w');
if fid == -1
    error('Could not open userConfig.m for writing.');
end
fwrite(fid, txt);
fclose(fid);
end 