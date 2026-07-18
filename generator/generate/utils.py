import pandas as pd
from generator.config import CSV_DIR

def save_to_csv(df: pd.DataFrame, filename: str):
    """
    Saves a Pandas DataFrame to a CSV file in the configured CSV_DIR.
    Ensures all column values are properly encoded.
    """
    target_path = CSV_DIR / filename
    # Save with utf-8 encoding, using standard comma separator and quoting when required
    df.to_csv(target_path, index=False, header=True, encoding="utf-8")
    print(f"Generated {len(df):,} records in {filename}")
