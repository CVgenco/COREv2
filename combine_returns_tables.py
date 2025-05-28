#!/usr/bin/env python3
"""
combine_returns_tables.py
Combine individual returnsTable_*.mat files into a single table format for Sprint 2
"""

import scipy.io
import numpy as np
import os

def combine_returns_tables():
    print("=== Combining Returns Tables for Sprint 2 ===")
    
    # List of products
    products = ['nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', 
                'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts']
    
    # Dictionary to store all returns data
    combined_returns = {}
    timestamps = None
    
    # Load each individual file
    for product in products:
        filename = f'EDA_Results/returnsTable_{product}.mat'
        
        if os.path.exists(filename):
            print(f"Loading {filename}... ", end="")
            try:
                # Load the MAT file
                data = scipy.io.loadmat(filename)
                
                # Find the main variable (should be returnsTable)
                main_vars = [key for key in data.keys() if not key.startswith('__')]
                
                if 'returnsTable' in main_vars:
                    returns_data = data['returnsTable']
                    
                    # Extract the returns values (typically the main data column)
                    if hasattr(returns_data, 'dtype') and returns_data.dtype.names:
                        # Structured array - get the main data field
                        field_names = returns_data.dtype.names
                        # Look for the product name or the first non-timestamp field
                        data_field = None
                        for field in field_names:
                            if product in field or (field != 'Timestamp' and field != 'Time'):
                                data_field = field
                                break
                        
                        if data_field:
                            combined_returns[product] = returns_data[data_field].flatten()
                        else:
                            # Use the first field that's not timestamp-related
                            non_time_fields = [f for f in field_names if 'time' not in f.lower() and 'date' not in f.lower()]
                            if non_time_fields:
                                combined_returns[product] = returns_data[non_time_fields[0]].flatten()
                            else:
                                combined_returns[product] = returns_data[field_names[0]].flatten()
                    else:
                        # Simple array
                        combined_returns[product] = returns_data.flatten()
                    
                    print(f"✓ {len(combined_returns[product])} returns")
                    
                else:
                    print("❌ No returnsTable variable found")
                    combined_returns[product] = np.array([])
                    
            except Exception as e:
                print(f"❌ Error: {e}")
                combined_returns[product] = np.array([])
        else:
            print(f"❌ File not found: {filename}")
            combined_returns[product] = np.array([])
    
    # Save the combined file in the expected format
    print("\nSaving combined returnsTable.mat...")
    try:
        scipy.io.savemat('EDA_Results/returnsTable.mat', 
                        {'returnsTable': combined_returns})
        print("✅ Successfully saved EDA_Results/returnsTable.mat")
        
        # Verification
        print("\n=== Verification ===")
        test_data = scipy.io.loadmat('EDA_Results/returnsTable.mat')
        returns_table = test_data['returnsTable']
        
        print("Combined returns table contains:")
        for product in products:
            if product in combined_returns and len(combined_returns[product]) > 0:
                n_returns = len(combined_returns[product])
                n_valid = np.sum(~np.isnan(combined_returns[product]))
                print(f"  ✓ {product}: {n_returns} returns ({n_valid} valid)")
            else:
                print(f"  ❌ {product}: No data")
                
        print("\n🚀 Returns table ready for Sprint 2!")
        
    except Exception as e:
        print(f"❌ Error saving file: {e}")
        return False
    
    return True

if __name__ == "__main__":
    combine_returns_tables()
