#!/usr/bin/env python3
"""
combine_regime_labels.py
Combine individual regimeLabels_*.mat files into a single struct format for Sprint 2
"""

import scipy.io
import numpy as np
import os

def combine_regime_labels():
    print("=== Combining Regime Labels for Sprint 2 ===")
    
    # List of products based on the files we saw
    products = ['nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', 
                'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts']
    
    # Initialize combined structure
    combined_regime_labels = {}
    
    # Load each individual file
    for product in products:
        filename = f'EDA_Results/regimeLabels_{product}.mat'
        
        if os.path.exists(filename):
            print(f"Loading {filename}... ", end="")
            try:
                # Load the MAT file
                data = scipy.io.loadmat(filename)
                
                # Find the main variable (ignore MATLAB metadata)
                main_vars = [key for key in data.keys() if not key.startswith('__')]
                
                if main_vars:
                    var_name = main_vars[0]
                    regime_data = data[var_name]
                    
                    # Flatten if it's a 2D array with one dimension = 1
                    if regime_data.ndim == 2 and (regime_data.shape[0] == 1 or regime_data.shape[1] == 1):
                        regime_data = regime_data.flatten()
                    
                    combined_regime_labels[product] = regime_data
                    
                    # Print some stats
                    valid_regimes = regime_data[~np.isnan(regime_data)]
                    unique_regimes = np.unique(valid_regimes)
                    print(f"✓ {len(regime_data)} obs, regimes: {unique_regimes}")
                    
                else:
                    print("❌ No data variables found")
                    combined_regime_labels[product] = np.array([])
                    
            except Exception as e:
                print(f"❌ Error: {e}")
                combined_regime_labels[product] = np.array([])
        else:
            print(f"❌ File not found: {filename}")
            combined_regime_labels[product] = np.array([])
    
    # Save the combined file
    print("\nSaving combined regimeLabels.mat...")
    try:
        scipy.io.savemat('EDA_Results/regimeLabels.mat', 
                        {'regimeLabels': combined_regime_labels})
        print("✅ Successfully saved EDA_Results/regimeLabels.mat")
        
        # Verification
        print("\n=== Verification ===")
        test_data = scipy.io.loadmat('EDA_Results/regimeLabels.mat')
        regime_labels_struct = test_data['regimeLabels']
        
        print("Combined structure contains:")
        for product in products:
            if product in [field[0] for field in regime_labels_struct.dtype.names or []]:
                print(f"  ✓ {product}")
            else:
                print(f"  ❌ {product} missing")
                
        print("\n🚀 Ready for Sprint 2: Parameter Estimation!")
        
    except Exception as e:
        print(f"❌ Error saving file: {e}")
        return False
    
    return True

if __name__ == "__main__":
    combine_regime_labels()
