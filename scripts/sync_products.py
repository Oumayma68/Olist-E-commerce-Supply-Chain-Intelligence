import logging
import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from elasticsearch import Elasticsearch, helpers


# --------------------------------------------------
# Configuration
# --------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

DB_CONFIG = {
    "host": os.environ["POSTGRES_HOST"],
    "port": os.environ["POSTGRES_PORT"],
    "dbname": os.environ["POSTGRES_DB"],
    "user": os.environ["POSTGRES_USER"],
    "password": os.environ["POSTGRES_PASSWORD"],
}

ELASTICSEARCH_URL = os.getenv(
    "ELASTICSEARCH_URL",
    "http://localhost:9200",
)

INDEX_NAME = "olist_products"
BATCH_SIZE = 500

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


# --------------------------------------------------
# Elasticsearch index mapping
# --------------------------------------------------

INDEX_MAPPING = {
    "properties": {
        "product_id": {
            "type": "keyword",
        },
        "product_category_name": {
            "type": "text",
            "fields": {
                "keyword": {
                    "type": "keyword",
                }
            },
        },
        "category_suggest": {
            "type": "completion",
        },
        "product_name_length": {
            "type": "integer",
        },
        "product_description_length": {
            "type": "integer",
        },
        "product_photos_qty": {
            "type": "integer",
        },
        "product_weight_g": {
            "type": "integer",
        },
        "product_length_cm": {
            "type": "integer",
        },
        "product_height_cm": {
            "type": "integer",
        },
        "product_width_cm": {
            "type": "integer",
        },
    }
}


def create_index(es: Elasticsearch) -> None:
    """Create the products index if it does not exist."""

    if es.indices.exists(index=INDEX_NAME):
        logger.info("Index '%s' already exists.", INDEX_NAME)
        return

    es.indices.create(
        index=INDEX_NAME,
        mappings=INDEX_MAPPING,
    )

    logger.info("Index '%s' created.", INDEX_NAME)


# --------------------------------------------------
# Read products from PostgreSQL
# --------------------------------------------------

def fetch_products():
    """Read current products from the dbt dimension."""

    query = """
        SELECT
            product_id,
            product_category_name,
            product_name_length,
            product_description_length,
            product_photos_qty,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        FROM analytics.dim_products
        WHERE is_current = TRUE
          AND product_id IS NOT NULL
    """

    with psycopg.connect(**DB_CONFIG) as connection:
        with connection.cursor() as cursor:
            cursor.execute(query)

            while rows := cursor.fetchmany(BATCH_SIZE):
                columns = [
                    description.name
                    for description in cursor.description
                ]

                for row in rows:
                    yield dict(zip(columns, row))


# --------------------------------------------------
# Synchronize products with Elasticsearch
# --------------------------------------------------

def sync_products(es: Elasticsearch) -> int:
    """Index products in batches using product_id as document ID."""

    indexed_count = 0

    def actions():
        for product in fetch_products():
            category = product["product_category_name"]

            # Convert the PostgreSQL row into an Elasticsearch document.
            document = dict(product)

            if category:
                document["category_suggest"] = {
                    "input": [category.replace("_", " ")],
                }

            yield {
                "_op_type": "index",
                "_index": INDEX_NAME,
                "_id": product["product_id"],
                "_source": document,
            }

    for success, item in helpers.streaming_bulk(
        es,
        actions(),
        chunk_size=BATCH_SIZE,
        raise_on_error=False,
        raise_on_exception=True,
    ):
        if success:
            indexed_count += 1
        else:
            logger.error("Indexing error: %s", item)

    logger.info(
        "Synchronization completed: %s products indexed.",
        indexed_count,
    )

    return indexed_count


# --------------------------------------------------
# Fuzzy search
# --------------------------------------------------

def fuzzy_search(es: Elasticsearch, text: str, size: int = 10) -> list:
    """Search product categories while tolerating small spelling errors."""
    text = text.strip().replace(" ", "_")
    response = es.search(
        index=INDEX_NAME,
        size=size,
        query={
            "match": {
                "product_category_name": {
                    "query": text,
                    "fuzziness": "AUTO",
                }
            }
        },
    )

    return [
        hit["_source"]
        for hit in response["hits"]["hits"]
    ]


# --------------------------------------------------
# Category autocomplete
# --------------------------------------------------

def autocomplete_categories(
    es: Elasticsearch,
    text: str,
    size: int = 10,
) -> list:
    """Suggest product categories as the user types."""

    response = es.search(
        index=INDEX_NAME,
        size=0,
        suggest={
            "category_suggestions": {
                "prefix": text,
                "completion": {
                    "field": "category_suggest",
                    "skip_duplicates": True,
                    "size": size,
                },
            }
        },
    )

    return [
        option["text"]
        for option in response["suggest"]["category_suggestions"][0][
            "options"
        ]
    ]


# --------------------------------------------------
# Main
# --------------------------------------------------

def main() -> None:
    logger.info("Connecting to Elasticsearch at %s", ELASTICSEARCH_URL)

    es = Elasticsearch(ELASTICSEARCH_URL)

    try:
        if not es.ping():
            raise ConnectionError("Elasticsearch is not responding.")

        logger.info("Elasticsearch connection successful.")

        create_index(es)
        sync_products(es)

        logger.info("Elasticsearch synchronization finished.")

    finally:
        es.close()


if __name__ == "__main__":
    main()