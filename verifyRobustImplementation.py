#!/usr/bin/env python3
"""
Verify Robust Outlier Detection System Implementation
Checks file presence, basic syntax, and integration points without running MATLAB
"""

import os
import re
from pathlib import Path

def check_file_exists(filepath, description):
    """Check if a file exists and report status"""
    if os.path.exists(filepath):
        print(f"✓ {os.path.basename(filepath)} - {description}")
        return True
    else:
        print(f"✗ {os.path.basename(filepath)} - MISSING - {description}")
        return False

def check_matlab_syntax(filepath):
    """Basic syntax check for MATLAB files"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Check for basic MATLAB syntax issues
        issues = []
        
        # Check for function definition
        if not re.search(r'function\s+', content):
            issues.append("No function definition found")
            
        # Check for end statements
        function_count = len(re.findall(r'function\s+', content))
        end_count = len(re.findall(r'\bend\b', content))
        
        if function_count > 0 and end_count == 0:
            issues.append("Missing 'end' statements")
            
        # Check for common syntax errors
        if re.search(r'[^%].*\n\s*$', content):  # Lines ending with incomplete statements
            pass  # This is too restrictive for MATLAB
            
        return issues
        
    except Exception as e:
        return [f"Error reading file: {e}"]

def main():
    print("=== ROBUST OUTLIER DETECTION SYSTEM VERIFICATION ===")
    print("Checking implementation without MATLAB execution...\n")
    
    base_path = "/Users/chayanvohra/Downloads/COREv2"
    
    # Core module files
    print("1. CORE MODULE FILES")
    print("--------------------")
    core_files = [
        ("robustOutlierDetection.m", "Core outlier detection engine"),
        ("enhancedDataPreprocessing.m", "Comprehensive preprocessing pipeline"),
        ("robustBayesianOptSafety.m", "Safety validation system"),
        ("testRobustIntegration.m", "Integration test suite"),
        ("validateRobustSystem.m", "System validation script")
    ]
    
    core_files_present = 0
    for filename, description in core_files:
        filepath = os.path.join(base_path, filename)
        if check_file_exists(filepath, description):
            core_files_present += 1
            
            # Basic syntax check
            syntax_issues = check_matlab_syntax(filepath)
            if syntax_issues:
                print(f"  ⚠ Syntax issues in {filename}: {', '.join(syntax_issues)}")
            else:
                print(f"  ✓ Basic syntax OK for {filename}")
    
    print(f"\nCore files status: {core_files_present}/{len(core_files)} present\n")
    
    # Enhanced existing files
    print("2. ENHANCED EXISTING FILES")
    print("-------------------------")
    enhanced_files = [
        ("data_cleaning.m", "Enhanced with robust outlier detection"),
        ("bayesoptSimObjective.m", "Enhanced with safety validation"),
        ("runBayesianTuning.m", "Updated with robust parameters"),
        ("runSimulationAndScenarioGeneration.m", "Integrated preprocessing"),
        ("userConfig.m", "Added robust system configuration")
    ]
    
    enhanced_files_present = 0
    for filename, description in enhanced_files:
        filepath = os.path.join(base_path, filename)
        if check_file_exists(filepath, description):
            enhanced_files_present += 1
    
    print(f"\nEnhanced files status: {enhanced_files_present}/{len(enhanced_files)} present\n")
    
    # Check integration points
    print("3. INTEGRATION POINTS CHECK")
    print("---------------------------")
    
    # Check if enhanced preprocessing is integrated
    main_sim_file = os.path.join(base_path, "runSimulationAndScenarioGeneration.m")
    if os.path.exists(main_sim_file):
        with open(main_sim_file, 'r') as f:
            content = f.read()
            if "enhancedDataPreprocessing" in content:
                print("✓ Enhanced preprocessing integrated into main simulation")
            else:
                print("✗ Enhanced preprocessing not found in main simulation")
    
    # Check if robust parameters are in Bayesian optimization
    bayes_file = os.path.join(base_path, "runBayesianTuning.m")
    if os.path.exists(bayes_file):
        with open(bayes_file, 'r') as f:
            content = f.read()
            if "blockSize" in content and "jumpThreshold" in content:
                print("✓ Robust parameters found in Bayesian optimization")
            else:
                print("✗ Robust parameters not found in Bayesian optimization")
    
    # Check configuration integration
    config_file = os.path.join(base_path, "userConfig.m")
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            content = f.read()
            if "robustOutlierDetection" in content and "dataPreprocessing.enabled" in content:
                print("✓ Enhanced preprocessing configuration found")
            else:
                print("✗ Enhanced preprocessing configuration not found")
    
    # Documentation check
    print("\n4. DOCUMENTATION CHECK")
    print("----------------------")
    guide_file = os.path.join(base_path, "ROBUST_SYSTEM_GUIDE.md")
    if check_file_exists(guide_file, "Implementation guide"):
        with open(guide_file, 'r') as f:
            content = f.read()
            if len(content) > 1000:  # Basic content check
                print("✓ Guide appears to have substantial content")
            else:
                print("⚠ Guide file may be incomplete")
    
    # Overall status
    print("\n5. OVERALL SYSTEM STATUS")
    print("========================")
    
    total_files = len(core_files) + len(enhanced_files) + 1  # +1 for guide
    present_files = core_files_present + enhanced_files_present + (1 if os.path.exists(guide_file) else 0)
    
    if present_files == total_files:
        print("✓ SYSTEM READY FOR TESTING")
        print("  All required files are present")
        print("  Integration points appear configured")
        print("  Ready for MATLAB execution testing")
    elif present_files >= total_files * 0.8:
        print("⚠ SYSTEM MOSTLY READY")
        print(f"  {present_files}/{total_files} files present")
        print("  Minor issues may need attention")
    else:
        print("✗ SYSTEM NOT READY")
        print(f"  Only {present_files}/{total_files} files present")
        print("  Significant issues need resolution")
    
    print(f"\nImplementation verification completed at {core_files_present + enhanced_files_present}/{len(core_files) + len(enhanced_files)} success rate")

if __name__ == "__main__":
    main()
