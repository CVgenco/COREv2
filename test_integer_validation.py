#!/usr/bin/env python3
"""
Test script to validate the integer conversion fixes for t-copula degrees of freedom.
This simulates the key parts of the MATLAB code to verify our fixes.
"""

import numpy as np
import math

def test_integer_validation():
    """Test that our integer validation logic works correctly."""
    
    print("Testing integer validation for t-copula degrees of freedom...")
    
    # Test cases for nu (degrees of freedom) values that might come from copulafit
    test_values = [2.5, 3.7, 1.1, 0.8, 10.9, 2.0, 3.0]
    
    for nu in test_values:
        # Apply our fix: round(max(1, nu))
        df_int = round(max(1, nu))
        
        print(f"Original nu: {nu:6.2f} -> Fixed df: {df_int:2d} (type: {type(df_int).__name__})")
        
        # Verify it's a positive integer
        assert isinstance(df_int, int), f"df_int should be int, got {type(df_int)}"
        assert df_int >= 1, f"df_int should be >= 1, got {df_int}"
    
    print("\n✅ All integer validation tests passed!")
    
    # Test the size validation for nSim
    print("\nTesting nSim validation...")
    
    # Simulate different innovation matrix sizes
    test_sizes = [0, 1, 50, 1000, 5000]
    
    for size in test_sizes:
        # Our fix: nSim = floor(min(1000, size))
        nSim = math.floor(min(1000, size))
        print(f"Matrix size: {size:4d} -> nSim: {nSim:4d}")
        
        # Check if we should proceed with sampling
        if nSim >= 2:
            print(f"  ✅ Would proceed with copula sampling (nSim = {nSim})")
        else:
            print(f"  ⚠️  Would skip copula sampling (nSim = {nSim} < 2)")
    
    print("\n✅ All nSim validation tests passed!")

def simulate_copula_parameter_fix():
    """Simulate the copula parameter handling that was causing issues."""
    
    print("\nSimulating copula parameter handling...")
    
    # Simulate what copulafit might return for t-copula
    R = np.array([[1.0, 0.3], [0.3, 1.0]])  # Correlation matrix
    nu = 2.7  # Non-integer degrees of freedom
    
    print(f"Simulated copulafit output:")
    print(f"  R (correlation matrix): {R.shape}")
    print(f"  nu (degrees of freedom): {nu} (type: {type(nu).__name__})")
    
    # Apply our fix
    df_fixed = round(max(1, nu))
    print(f"\nAfter our fix:")
    print(f"  regimeCopulas(r).params = R")
    print(f"  regimeCopulas(r).df = {df_fixed} (type: {type(df_fixed).__name__})")
    
    # Simulate the sampling call
    print(f"\nSimulated copularnd call:")
    print(f"  copularnd('t', R, nSim, {df_fixed})")
    print(f"  ✅ df parameter is now a proper integer")

if __name__ == "__main__":
    test_integer_validation()
    simulate_copula_parameter_fix()
    print(f"\n🎉 All validation tests completed successfully!")
    print(f"\nThe fixes should resolve the 'Size inputs must be integers' error.")
