import os
import csv
from pathlib import Path

import psycopg
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"

load_dotenv(BASE_DIR / ".env")

DB_CONFIG = {
    "host": os.environ["POSTGRES_HOST"],
    "port": os.environ["POSTGRES_PORT"],
    "dbname": os.environ["POSTGRES_DB"],
    "user": os.environ["POSTGRES_USER"],
    "password": os.environ["POSTGRES_PASSWORD"],
}


DATASETS = {
    "olist_customers_dataset.csv": "raw_olist.raw_customers",
    "olist_orders_dataset.csv": "raw_olist.raw_orders",
    "olist_order_items_dataset.csv": "raw_olist.raw_order_items",
    "olist_order_payments_dataset.csv": "raw_olist.raw_payments",
    "olist_products_dataset.csv": "raw_olist.raw_products",
    "olist_sellers_dataset.csv": "raw_olist.raw_sellers",
}


def count_csv_rows(file_path: Path) -> int:
    with file_path.open("r", encoding="utf-8", newline="") as file:
        return sum(1 for _ in csv.reader(file)) - 1


def load_csv(connection, file_path: Path, table_name: str) -> int:
    expected_rows = count_csv_rows(file_path)

    with connection.cursor() as cursor:
        cursor.execute(f"TRUNCATE TABLE {table_name}")

        with file_path.open("r", encoding="utf-8", newline="") as file:
            with cursor.copy(
                f"""
                COPY {table_name}
                FROM STDIN
                WITH (
                    FORMAT csv,
                    HEADER true
                )
                """
            ) as copy:
                while data := file.read(1024 * 1024):
                    copy.write(data)

        cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
        actual_rows = cursor.fetchone()[0]

    if actual_rows != expected_rows:
        raise RuntimeError(
            f"{table_name}: expected {expected_rows} rows, "
            f"but loaded {actual_rows}"
        )

    return actual_rows


def main():
    print(f"Data directory: {DATA_DIR}")

    missing_files = [
        filename
        for filename in DATASETS
        if not (DATA_DIR / filename).exists()
    ]

    if missing_files:
        raise FileNotFoundError(
            f"Missing CSV files: {', '.join(missing_files)}"
        )

    with psycopg.connect(**DB_CONFIG) as connection:
        for filename, table_name in DATASETS.items():
            file_path = DATA_DIR / filename

            print(f"Loading {filename} -> {table_name}")

            row_count = load_csv(
                connection,
                file_path,
                table_name,
            )

            print(f"  Loaded {row_count:,} rows")

        connection.commit()

    print("Raw ingestion completed successfully.")


if __name__ == "__main__":
    main()
