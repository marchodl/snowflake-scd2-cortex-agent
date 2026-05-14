CREATE OR REPLACE SEMANTIC VIEW GDS_HA_MARC_MEDAWAR.SEMANTIC.SV_CUSTOMER_PRODUCT_HOLDINGS

    TABLES (
        GDS_HA_MARC_MEDAWAR.CURATED.DIM_CUSTOMER_SCD2
            UNIQUE (CUSTOMER_ID)
            COMMENT = 'Customers tracked over time via SCD Type 2. Each record represents one version of a customer between VALID_FROM and VALID_TO.',
        GDS_HA_MARC_MEDAWAR.CURATED.DIM_PRODUCT
            PRIMARY KEY (PRODUCT_ID)
            COMMENT = 'Product master with three-level hierarchical classification (group → category → type) and derived IS_MORTGAGE / IS_PNC_INSURANCE flags.',
        GDS_HA_MARC_MEDAWAR.CURATED.FCT_CUSTOMER_PRODUCT_HOLDING_SCD2
            COMMENT = 'Customer × product holdings tracked over time via SCD Type 2 at the holding_id grain. Each record represents one version of a holding between VALID_FROM and VALID_TO.'
    )

    RELATIONSHIPS (
        HOLDING_TO_CUSTOMER AS
            FCT_CUSTOMER_PRODUCT_HOLDING_SCD2(CUSTOMER_ID)
            REFERENCES DIM_CUSTOMER_SCD2(CUSTOMER_ID),
        HOLDING_TO_PRODUCT AS
            FCT_CUSTOMER_PRODUCT_HOLDING_SCD2(PRODUCT_ID)
            REFERENCES DIM_PRODUCT(PRODUCT_ID)
    )

    FACTS (
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.AMOUNT AS AMOUNT
            COMMENT = 'The monetary amount associated with a customer''s product holding.'
    )

    DIMENSIONS (
        -- Customer dimensions
        DIM_CUSTOMER_SCD2.CUSTOMER_ID            AS CUSTOMER_ID            COMMENT = 'Unique identifier assigned to each customer.',
        DIM_CUSTOMER_SCD2.FIRST_NAME             AS FIRST_NAME             COMMENT = 'The first name of the customer.',
        DIM_CUSTOMER_SCD2.LAST_NAME              AS LAST_NAME              COMMENT = 'The last name of the customer.',
        DIM_CUSTOMER_SCD2.NATIONAL_ID            AS NATIONAL_ID            COMMENT = 'Norwegian national identification number (fødselsnummer).',
        DIM_CUSTOMER_SCD2.BIRTH_DATE             AS BIRTH_DATE             COMMENT = 'The date of birth of the customer.',
        DIM_CUSTOMER_SCD2.REGION_CODE            AS REGION_CODE            COMMENT = 'Short regional code (e.g. OSL, VST, NDL).',
        DIM_CUSTOMER_SCD2.REGION_NAME            AS REGION_NAME            COMMENT = 'Norwegian region name (e.g. Oslo, Vestland, Nordland).',
        DIM_CUSTOMER_SCD2.SEGMENT_CODE           AS SEGMENT_CODE           COMMENT = 'Customer segment classification: MM (Mass Market), AFL (Affluent), PB (Private Banking), YP (Young Professional).',
        DIM_CUSTOMER_SCD2.CUSTOMER_STATUS_CODE   AS CUSTOMER_STATUS_CODE   COMMENT = 'Current state of the customer (e.g. ACT).',
        DIM_CUSTOMER_SCD2.VALID_FROM             AS CUSTOMER_VALID_FROM    COMMENT = 'Inclusive start of this customer SCD2 version.',
        DIM_CUSTOMER_SCD2.VALID_TO               AS CUSTOMER_VALID_TO      COMMENT = 'Exclusive end of this customer SCD2 version; 9999-12-31 means open / current.',
        DIM_CUSTOMER_SCD2.IS_CURRENT             AS CUSTOMER_IS_CURRENT    COMMENT = 'TRUE if this is the current active customer version.',

        -- Product dimensions
        DIM_PRODUCT.PRODUCT_ID                   AS PRODUCT_ID             COMMENT = 'Unique identifier assigned to each product.',
        DIM_PRODUCT.PRODUCT_NAME                 AS PRODUCT_NAME           COMMENT = 'The full name of the financial product.',
        DIM_PRODUCT.PRODUCT_GROUP_CODE           AS PRODUCT_GROUP_CODE     COMMENT = 'Short code identifying the product group (LND, INS, DEP, CRD).',
        DIM_PRODUCT.PRODUCT_GROUP_NAME           AS PRODUCT_GROUP_NAME     COMMENT = 'Product group name (Lending, Insurance, Deposits, Cards).',
        DIM_PRODUCT.PRODUCT_CATEGORY_CODE        AS PRODUCT_CATEGORY_CODE  COMMENT = 'Short product category code (MORT, PNC, LIFE, SAVE, CARD).',
        DIM_PRODUCT.PRODUCT_CATEGORY_NAME        AS PRODUCT_CATEGORY_NAME  COMMENT = 'Product category name (Mortgage, P&C Insurance, Life Insurance, Savings, Credit Card).',
        DIM_PRODUCT.PRODUCT_TYPE_CODE            AS PRODUCT_TYPE_CODE      COMMENT = 'Short product type code (e.g. HOME_STD, HOME_FLX, PROP, AUTO).',
        DIM_PRODUCT.PRODUCT_TYPE_NAME            AS PRODUCT_TYPE_NAME      COMMENT = 'Product type name (e.g. Home Loan, Property Insurance, Vehicle Insurance).',
        DIM_PRODUCT.IS_MORTGAGE                  AS IS_MORTGAGE            COMMENT = 'TRUE if the product is in the Mortgage category.',
        DIM_PRODUCT.IS_PNC_INSURANCE             AS IS_PNC_INSURANCE       COMMENT = 'TRUE if the product is in the Property and Casualty (P&C) Insurance category — covers property, vehicle, and travel insurance.',

        -- Holding dimensions
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.HOLDING_ID     AS HOLDING_ID         COMMENT = 'Unique identifier assigned to each customer product holding (natural primary key in source).',
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.CUSTOMER_ID    AS HOLDING_CUSTOMER_ID COMMENT = 'Customer identifier on the holding (joins to DIM_CUSTOMER_SCD2).',
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.PRODUCT_ID     AS HOLDING_PRODUCT_ID  COMMENT = 'Product identifier on the holding (joins to DIM_PRODUCT).',
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.CURRENCY_CODE  AS CURRENCY_CODE      COMMENT = 'Currency of the holding amount; NOK throughout this dataset.',
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.VALID_FROM     AS HOLDING_VALID_FROM COMMENT = 'Inclusive start of this holding SCD2 version.',
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.VALID_TO       AS HOLDING_VALID_TO   COMMENT = 'Exclusive end of this holding SCD2 version; 9999-12-31 means open / current.',
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.IS_CURRENT     AS HOLDING_IS_CURRENT COMMENT = 'TRUE if this is the current active holding version.'
    )

    METRICS (
        FCT_CUSTOMER_PRODUCT_HOLDING_SCD2.TOTAL_HOLDING_AMOUNT AS SUM(AMOUNT)
            WITH SYNONYMS = (
                'total amount',
                'sum of amount',
                'total balance',
                'total exposure',
                'total holdings',
                'amount sum'
            )
            COMMENT = 'Sum of holding amount in NOK. Represents different concepts depending on product category: outstanding loan balance for mortgages, annual premium for insurance products (P&C, Life), account balance for savings, and credit limit for credit cards. Aggregates are most meaningful when scoped to a single product category. For mortgage customers, this metric represents total outstanding mortgage exposure.'
    );
