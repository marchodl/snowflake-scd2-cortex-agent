# snowflake-scd2-cortex-agent
End-to-end Snowflake pipeline: CDC → SCD Type 2 → Semantic View → Cortex Agent for natural-language analytics

## 1. Overview

End-to-end pipeline transforming raw CDC data into a historized SCD Type 2 model,
exposed through a Snowflake Semantic View and queryable in natural language via a
Cortex Agent.

*Schemas inside GDS_HA_MARC_MEDAWAR:*
- STAGING  deduped, normalized views over raw
- CURATED  SCD2 tables and product dimension
- SEMANTIC  Snowflake Semantic View + Cortex Agent

## 2. Data model

| Object | Grain | Keys |
|---|---|---|
| CURATED.DIM_CUSTOMER_SCD2 | one row per (customer_id, valid_from) | unique: CUSTOMER_ID (logical) |
| CURATED.FCT_CUSTOMER_PRODUCT_HOLDING_SCD2 | one row per (holding_id, valid_from) |  PK: HOLDING_ID |
| CURATED.DIM_PRODUCT | one row per product | PK: PRODUCT_ID |

SCD2 tables have VALID_FROM, VALID_TO, IS_CURRENT.
DIM_PRODUCT has derived IS_MORTGAGE, IS_PNC_INSURANCE flags.

*Relationships (many-to-one):*
- FCT_..._HOLDING_SCD2.CUSTOMER_ID → DIM_CUSTOMER_SCD2.CUSTOMER_ID
- FCT_..._HOLDING_SCD2.PRODUCT_ID → DIM_PRODUCT.PRODUCT_ID

*Metric:* TOTAL_HOLDING_AMOUNT = SUM(AMOUNT) in NOK. Means different things by
category (loan balance for mortgages, premium for insurance); aggregates are most
meaningful when scoped to a single product category.

## 3. CDC → SCD2 conversion

*Dedupe (staging):* replay duplicates handled by keeping the latest ingested_at
per source_event_id. Codes normalized with UPPER(TRIM(...)) to neutralize raw
formatting noise (" pnc ", " mm ", " act ").

*SCD2 versioning (curated):* each CDC event becomes one version.

sql
valid_from = event_datetime
valid_to   = COALESCE(
    LEAD(event_datetime) OVER (PARTITION BY entity_id ORDER BY event_datetime),
    TIMESTAMP '9999-12-31 00:00:00'
)
is_current = (valid_to = TIMESTAMP '9999-12-31 00:00:00')


*Delete handling:* D events are filtered from the final SCD2 (WHERE cdc_operation != 'D').
Their effect is captured implicitly, the LEAD window on the prior version ends that
version's validity at the D timestamp. After a delete, the entity has no current row.


## 4. Semantic view & Cortex Agent

*Semantic view:* GDS_HA_MARC_MEDAWAR.SEMANTIC.SV_CUSTOMER_PRODUCT_HOLDINGS
Built via Snowsight UI. Exposes 3 tables, 2 relationships, 1 metric.

*Cortex Agent:* GDS_HA_MARC_MEDAWAR.SEMANTIC.[AGENT_NAME]
Tool: Cortex Analyst on the semantic view above.
Custom instructions encode SCD2 point-in-time logic and metric scoping.

*How to use:* Snowsight → AI & ML → Agents → [AGENT_NAME] → Chat.

## 5. Validation results (as of 2025-12-31)

| # | Prompt | Answer |
|---|---|---|
| 1 | Which customers have a mortgage but no P&C insurance as of 2025-12-31? | 19 customers (list returned) |
| 2 | How many customers have a mortgage as of 2025-12-31? | 50 |
| 3 | How many customers have P&C insurance as of 2025-12-31? | 64 |
| 4 | What is the total mortgage exposure as of 2025-12-31? | 188,746,000 NOK (~188.7M) |
| 5 | How many customers in each region have a mortgage as of 2025-12-31? | Oslo leads with 12 mortgage customers, followed by Troms and Agder with 7 each. The total across all 8 regions is 50 customers, |

All answers cross-checked with direct SQL queries against the curated SCD2 tables.
