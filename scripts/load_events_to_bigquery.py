import argparse
from pathlib import Path

import pandas as pd
from google.cloud import bigquery


EXPECTED_COLUMNS = [
    "event_time",
    "user_id",
    "gender",
    "event_type",
    "transaction_category",
    "miles_amount",
    "platform",
    "utm_source",
    "country",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load event CSV into BigQuery raw table.")
    parser.add_argument("--csv-path", required=True, help="Absolute path to source event CSV.")
    parser.add_argument("--project-id", required=True, help="GCP project ID.")
    parser.add_argument("--dataset", required=True, help="BigQuery dataset name.")
    parser.add_argument("--table", default="events", help="BigQuery destination table.")
    return parser.parse_args()


def validate_columns(df: pd.DataFrame) -> None:
    missing = sorted(set(EXPECTED_COLUMNS) - set(df.columns))
    if missing:
        raise ValueError(f"Missing required columns in input CSV: {missing}")


def load_csv(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    validate_columns(df)
    df["event_time"] = pd.to_datetime(df["event_time"], utc=True, errors="coerce")
    if df["event_time"].isna().any():
        raise ValueError("Invalid event_time values found; aborting load.")

    # Keep miles nullable for non-miles events, but coerce non-numeric values to null.
    df["miles_amount"] = pd.to_numeric(df["miles_amount"], errors="coerce")
    df["loaded_at"] = pd.Timestamp.utcnow()
    return df


def ensure_dataset(client: bigquery.Client, dataset_ref: bigquery.DatasetReference) -> None:
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = "asia-southeast1"
    client.create_dataset(dataset, exists_ok=True)


def main() -> None:
    args = parse_args()
    csv_path = Path(args.csv_path).expanduser().resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    df = load_csv(csv_path)
    client = bigquery.Client(project=args.project_id)
    dataset_ref = bigquery.DatasetReference(args.project_id, args.dataset)
    ensure_dataset(client, dataset_ref)
    table_id = f"{args.project_id}.{args.dataset}.{args.table}"

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE
    )

    load_job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    load_job.result()
    table = client.get_table(table_id)
    print(f"Loaded {table.num_rows} rows into {table_id}")


if __name__ == "__main__":
    main()
