#!/usr/bin/env python3
"""
Final verification script for CORE Sprint 3 & 5 execution readiness.
This simulates the key workflow steps to verify all fixes are in place.
"""

import os
import re

def check_file_exists(filepath, description):
    """Check if a file exists and print status."""
    if os.path.exists(filepath):
        print(f"✅ {description}: {filepath}")
        return True
    else:
        print(f"❌ {description}: {filepath} (NOT FOUND)")
        return False

def check_code_fix(filepath, pattern, description):
    """Check if a specific code fix is present in a file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
            if re.search(pattern, content, re.MULTILINE):
                print(f"✅ {description}")
                return True
            else:
                print(f"❌ {description}")
                return False
    except FileNotFoundError:
        print(f"❌ {description} - File not found: {filepath}")
        return False

def main():
    print("🔍 CORE Sprint 3 & 5 Execution Readiness Check")
    print("=" * 50)
    
    base_path = "/Users/chayanvohra/Downloads/COREv2"
    all_checks_passed = True
    
    # 1. Check essential files exist
    print("\n📁 Essential Files Check:")
    essential_files = [
        ("userConfig.m", "User Configuration"),
        ("runEmpiricalCopulaBootstrapping.m", "Sprint 3 Script"),
        ("runSimulationEngine.m", "Sprint 5 Script"),
        ("fit_copula_per_regime.m", "Copula Fitting Function"),
        ("custom_infer.m", "GARCH Inference Fallback")
    ]
    
    for filename, description in essential_files:
        filepath = os.path.join(base_path, filename)
        if not check_file_exists(filepath, description):
            all_checks_passed = False
    
    # 2. Check data dependencies
    print("\n📊 Data Dependencies Check:")
    data_files = [
        "EDA_Results/returnsTable.mat",
        "EDA_Results/innovationsStruct.mat", 
        "EDA_Results/regimeLabels.mat"
    ]
    
    for data_file in data_files:
        filepath = os.path.join(base_path, data_file)
        if not check_file_exists(filepath, f"Data file: {data_file}"):
            all_checks_passed = False
    
    # 3. Check copula structure was cleaned
    print("\n🧹 Cleanup Check:")
    copula_file = os.path.join(base_path, "EDA_Results/copulaStruct.mat")
    if not os.path.exists(copula_file):
        print("✅ Old copula structure removed (will be regenerated)")
    else:
        print("⚠️  Old copula structure still exists (should be regenerated)")
    
    # 4. Check critical code fixes
    print("\n🔧 Code Fixes Verification:")
    
    # Check fit_copula_per_regime.m fixes
    fit_copula_path = os.path.join(base_path, "fit_copula_per_regime.m")
    fixes = [
        (r"regimeCopulas\(r\)\.df = round\(max\(1, nu\)\)", "t-copula df integer conversion in fitting"),
        (r"df_int = round\(max\(1, regimeCopulas\(r\)\.df\)\)", "t-copula df integer validation in sampling"),
        (r"nSim = floor\(min\(1000, size\(innovMat,1\)\)\)", "Sample size validation"),
        (r"if nSim >= 2", "Minimum sample size check")
    ]
    
    for pattern, description in fixes:
        if not check_code_fix(fit_copula_path, pattern, f"Fix in fit_copula_per_regime.m: {description}"):
            all_checks_passed = False
    
    # Check runSimulationEngine.m fixes  
    sim_engine_path = os.path.join(base_path, "runSimulationEngine.m")
    sim_fixes = [
        (r"fieldnames\(returnsTable\)", "Struct-based data structure support"),
        (r"df_int = round\(max\(1, copula\.df\)\)", "t-copula df integer validation in simulation"),
        (r"copularnd\('t', copula\.params, 1, df_int\)", "Integer df parameter in copularnd call")
    ]
    
    for pattern, description in sim_fixes:
        if not check_code_fix(sim_engine_path, pattern, f"Fix in runSimulationEngine.m: {description}"):
            all_checks_passed = False
    
    # 5. Configuration check
    print("\n⚙️  Configuration Check:")
    config_path = os.path.join(base_path, "userConfig.m")
    if check_code_fix(config_path, r"config\.copulaType = 't'", "t-copula configuration"):
        print("  📝 System configured to use t-copulas (our fixes are relevant)")
    
    # 6. Summary
    print("\n" + "=" * 50)
    if all_checks_passed:
        print("🎉 ALL CHECKS PASSED!")
        print("\n📋 Ready for execution:")
        print("   1. Run Sprint 3: runEmpiricalCopulaBootstrapping('userConfig.m')")
        print("   2. Run Sprint 5: runSimulationEngine('userConfig.m')")
        print("   3. Continue with Sprints 6 & 7")
        print("\n💡 Our integer validation fixes should resolve the 'Size inputs must be integers' error.")
    else:
        print("⚠️  SOME CHECKS FAILED!")
        print("   Please review the failed checks above before proceeding.")
    
    return all_checks_passed

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
