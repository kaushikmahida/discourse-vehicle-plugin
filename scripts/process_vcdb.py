#!/usr/bin/env python3
"""
Process VCDB data into a compact JSON for the Discourse vehicle plugin.
Creates cascading lookup: Year -> Make -> Model -> Trim
"""

import json
import os
from collections import defaultdict

VCDB_DIR = "/Users/kaushikm/Documents/Code/RS2 Code/VCDB/AutoCare_VCdb_NA_LDPS_enUS_JSON_20250130"
OUTPUT_DIR = "/Users/kaushikm/Documents/Code/RS2 Code/prod_discourse_setup/discourse-vehicle-plugin/data"
MIN_YEAR = 1990

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    print("Loading VCDB files...")
    
    # Load lookup tables
    with open(os.path.join(VCDB_DIR, 'Make.json')) as f:
        makes_raw = json.load(f)
    makes = {m['MakeID']: m['MakeName'] for m in makes_raw}
    print(f"  Loaded {len(makes)} makes")
    
    with open(os.path.join(VCDB_DIR, 'Model.json')) as f:
        models_raw = json.load(f)
    models = {m['ModelID']: m['ModelName'] for m in models_raw}
    print(f"  Loaded {len(models)} models")
    
    with open(os.path.join(VCDB_DIR, 'SubModel.json')) as f:
        submodels_raw = json.load(f)
    submodels = {s['SubModelID']: s['SubModelName'] for s in submodels_raw}
    print(f"  Loaded {len(submodels)} submodels (trims)")
    
    # Load BaseVehicle to build Year -> Make -> Model relationships
    print("Loading BaseVehicle.json...")
    with open(os.path.join(VCDB_DIR, 'BaseVehicle.json')) as f:
        base_vehicles = json.load(f)
    print(f"  Loaded {len(base_vehicles)} base vehicles")
    
    # Load Vehicle to build BaseVehicle -> SubModel relationships
    print("Loading Vehicle.json...")
    with open(os.path.join(VCDB_DIR, 'Vehicle.json')) as f:
        vehicles = json.load(f)
    print(f"  Loaded {len(vehicles)} vehicles")
    
    # Build lookups
    print("Building lookup structures...")
    
    # year -> set of make_ids
    year_makes = defaultdict(set)
    # "year_makeId" -> set of model_ids
    year_make_models = defaultdict(set)
    # baseVehicleId -> {year, makeId, modelId}
    bv_lookup = {}
    
    for bv in base_vehicles:
        year = bv['YearID']
        if year < MIN_YEAR:
            continue
        make_id = bv['MakeID']
        model_id = bv['ModelID']
        bv_id = bv['BaseVehicleID']
        
        year_makes[year].add(make_id)
        year_make_models[f"{year}_{make_id}"].add(model_id)
        bv_lookup[bv_id] = {'year': year, 'make_id': make_id, 'model_id': model_id}
    
    # "year_makeId_modelId" -> set of submodel_ids
    ymm_submodels = defaultdict(set)
    
    for v in vehicles:
        bv_id = v['BaseVehicleID']
        submodel_id = v.get('SubmodelID')
        if bv_id in bv_lookup and submodel_id:
            bv = bv_lookup[bv_id]
            key = f"{bv['year']}_{bv['make_id']}_{bv['model_id']}"
            ymm_submodels[key].add(submodel_id)
    
    # Convert to output format with names
    print("Converting to output format...")
    
    output = {
        "years": sorted([y for y in year_makes.keys()], reverse=True),
        "makes": makes,
        "models": models,
        "submodels": submodels,
        "year_makes": {str(y): sorted(list(m)) for y, m in year_makes.items()},
        "year_make_models": {k: sorted(list(v)) for k, v in year_make_models.items()},
        "ymm_submodels": {k: sorted(list(v)) for k, v in ymm_submodels.items()}
    }
    
    # Write output
    output_file = os.path.join(OUTPUT_DIR, 'vcdb.json')
    print(f"Writing to {output_file}...")
    with open(output_file, 'w') as f:
        json.dump(output, f, separators=(',', ':'))
    
    size_mb = os.path.getsize(output_file) / (1024 * 1024)
    print(f"Done! Output size: {size_mb:.2f} MB")
    print(f"Years: {len(output['years'])}")
    print(f"Year-Make combos: {len(output['year_makes'])}")
    print(f"Year-Make-Model combos: {len(output['year_make_models'])}")
    print(f"YMM-Submodel combos: {len(output['ymm_submodels'])}")

if __name__ == '__main__':
    main()
