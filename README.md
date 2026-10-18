# Olist E-Commerce & Supply Chain Intelligence

This project is an end-to-end data platform that powers analytics for a Brazilian e-commerce marketplace ecosystem. It ingests millions of transaction records from Olist sellers and transforms raw operational data into a trusted, production-grade analytical foundation.

The architecture is built around three core stages:

* **Ingestion & Storage**: Automated CSV ingestion from Olist datasets into PostgreSQL raw schema, with built-in row validation and data lineage tracking.
* **Transformation & Modeling**: ELT data warehouse built with dbt Core, featuring historical tracking using Slowly Changing Dimensions (SCD Type 2) for products and sellers, and comprehensive dimensional models for orders, payments, and logistics.
* **Monitoring & Quality**: Rigorous Data Quality framework with automated health checks and Data Health Tiles that ensure analytical reliability across the entire pipeline.

The result is a governed data ecosystem that delivers trustworthy insights into marketplace performance, seller health, customer behavior, and supply chain efficiency.

## Current architecture

```mermaid
graph TD
    A["Olist CSV files"] --> B["Python ingestion script"]
    B --> C["PostgreSQL"]
    C --> D["raw_olist.raw_customers"]
    C --> E["raw_olist.raw_orders"]
    C --> F["raw_olist.raw_order_items"]
    C --> G["raw_olist.raw_payments"]
    C --> H["raw_olist.raw_products"]
    C --> I["raw_olist.raw_sellers"]
    H --> J["dbt snapshots"] 
    J --> K["snap_olist.snp_products"] 
    C --> L["dbt transformation layer"] 
    K --> L 
    L --> M["staging models"] 
    M --> N["analytical marts"]
    N --> O["mart_supply_chain_kpis"]
```

## Stack

- Ubuntu
- Docker 
- PostgreSQL 
- Python 
- dbt Core
- dbt-postgres

## Project structure
 
```
.
├── database/
│   ├── init/
│   │   └── 01_create_schema.sql
│   └── sql/
│       └── 01_create_raw_tables.sql
│
├── scripts/
│   └── load_raw.py
│
├── dbt_project/
│   ├── analyses/
│   ├── macros/
│   ├── models/
│   │   └── sources.yml
│   ├── snapshots/
│   │   └── snp_products.sql
│   ├── seeds/
│   ├── tests/
│   ├── dbt_project.yml
│   ├── packages.yml
│   ├── package-lock.yml
│   └── profiles.yml.example
│
├── data/              # ignored by Git
├── .env               # ignored by Git
├── docker-compose.yml
├── requirements.txt
└── README.md
```

## Phase 1 — Raw layer & staging

The first phase builds the PostgreSQL raw layer and prepares the dbt transformations.

### Data ingestion

The `scripts/load_raw.py` script checks the CSV files, loads them into PostgreSQL using `COPY`, and validates the loaded row counts.

### dbt setup

dbt Core with the PostgreSQL adapter, the `dbt_utils` and `dbt_expectations` packages, and a `profiles.yml.example` template. The local dbt profile (`~/.dbt/profiles.yml`) is not committed because it contains database credentials.

### Product snapshot — SCD Type 2

`snap_olist.snp_products` keeps the history of product attribute changes using a dbt snapshot (SCD Type 2). When a tracked attribute changes, the previous version is closed and a new one is created instead of overwriting the record.

### Staging models

Six staging models (`stg_customers`, `stg_orders`, `stg_order_items`, `stg_payments`, `stg_products`, `stg_sellers`) provide a standardized interface to the raw tables. The 1,000-row development limit has been removed: they now run on the full datasets.

## Phase 2 — Analytical modeling & data quality

This phase adds the analytical marts, business metrics and automated data quality tests. The marts are materialized as tables in the `analytics` schema.

| Model | Purpose |
|---|---|
| `dim_products` | Product attributes and historical versions (SCD Type 2) |
| `fct_orders` | Order lifecycle and delivery performance |
| `fct_order_items` | Item prices, freight costs and total item value |
| `fct_payments` | Payments, payment methods and installments |
| `mart_supply_chain_kpis` | Aggregated supply chain KPIs: order volume, late deliveries, average delivery time, item value, freight cost and freight-to-value ratio |

### Data quality

The project relies on dbt built-in tests, `dbt_utils` and `dbt_expectations`, plus custom generic and singular tests covering constraints, relationships and business rules.

Latest full run: **64 passed, 3 warnings, 0 errors**. The warnings come from known anomalies in the source data (inconsistent order, pickup and delivery dates), which are flagged rather than artificially corrected.

### Dbt documentation

Models and columns are documented in dbt.

