import json
from pathlib import Path

GROUND_TRUTH = {
    "inbody120": {
        "Age":                          51.0,
        "Gender":                       0.0,
        "Height":                       156.9,
        "Weight":                       59.1,
        "SMM_(Skeletal_Muscle_Mass)":   19.6,
        "BMR_(Basal_Metabolic_Rate)":   1176.0,
        "FFM_of_Trunk":                 None,
        "TBW_(Total_Body_Water)":       27.5,
        "ECW/TBW":                      None,
        "50kHz-Whole_Body_Phase_Angle": None,
        "BFM_(Body_Fat_Mass)":          21.8,
        "PBF_(Percent_Body_Fat)":       36.9,
    },
    "inbody270": {
        "Age":                          51.0,
        "Gender":                       0.0,
        "Height":                       156.9,
        "Weight":                       59.1,
        "SMM_(Skeletal_Muscle_Mass)":   19.6,
        "BMR_(Basal_Metabolic_Rate)":   1154.0,
        "FFM_of_Trunk":                 None,
        "TBW_(Total_Body_Water)":       26.5,
        "ECW/TBW":                      None,
        "50kHz-Whole_Body_Phase_Angle": None,
        "BFM_(Body_Fat_Mass)":          22.8,
        "PBF_(Percent_Body_Fat)":       38.6,
    },
    "inbody570": {
        "Age":                          31.0,
        "Gender":                       0.0,
        "Height":                       165.1,
        "Weight":                       61.42,
        "SMM_(Skeletal_Muscle_Mass)":   21.59,
        "BMR_(Basal_Metabolic_Rate)":   1231.0,
        "FFM_of_Trunk":                 17.96,
        "TBW_(Total_Body_Water)":       29.12,
        "ECW/TBW":                      0.376,
        "50kHz-Whole_Body_Phase_Angle": None,
        "BFM_(Body_Fat_Mass)":          21.51,
        "PBF_(Percent_Body_Fat)":       35.0,
    },
}

out_dir = Path("smart_fit_backend/tests/ground_truth")
out_dir.mkdir(parents=True, exist_ok=True)

for name, data in GROUND_TRUTH.items():
    with open(out_dir / f"{name}.json", "w") as f:
        json.dump(data, f, indent=2)

print("Generated ground truth files.")
