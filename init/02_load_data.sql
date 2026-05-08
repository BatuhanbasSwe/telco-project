-- =============================================================================
-- INIT SCRIPT 2/2 — CSV VERI IMPORT
-- Bu script docker-compose basladiginda 01_create_tables.sql'den sonra calisir.
-- Oracle External Tables yontemiyle CSV dosyalarindan veri okunur ve kalici
-- tablolara aktarilir. External tablolar dogrudan disk uzerindeki CSV'yi okur;
-- ayri bir SQL*Loader araç cagrisina gerek yoktur.
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- -----------------------------------------------------------------------------
-- TARIFFS: 4 satir, dogrudan INSERT ile yuklenir
-- -----------------------------------------------------------------------------
INSERT INTO TARIFFS VALUES (1, 'Genç Dinamik',  150,  10240,  600,   600);
INSERT INTO TARIFFS VALUES (2, 'Kurumsal SMS',  1000,     0,    0, 10000);
INSERT INTO TARIFFS VALUES (3, 'Çalışan GB',    450,  20480, 1000,   250);
INSERT INTO TARIFFS VALUES (4, 'Kobiye Destek', 350,  20480, 1000,  1000);
COMMIT;


-- -----------------------------------------------------------------------------
-- CUSTOMERS: External Table ile CSV okuma
-- -----------------------------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ext_customers';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_customers (
    CUSTOMER_ID NUMBER(10),
    NAME        VARCHAR2(200 CHAR),
    CITY        VARCHAR2(100 CHAR),
    SIGNUP_DATE VARCHAR2(20),
    TARIFF_ID   NUMBER(10)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY csv_data_dir
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        CHARACTERSET AL32UTF8
        STRING SIZES ARE IN CHARACTERS
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
        (CUSTOMER_ID, NAME, CITY, SIGNUP_DATE, TARIFF_ID)
    )
    LOCATION ('CUSTOMERS.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO CUSTOMERS (CUSTOMER_ID, NAME, CITY, SIGNUP_DATE, TARIFF_ID)
SELECT
    CUSTOMER_ID,
    NAME,
    CITY,
    TO_DATE(SIGNUP_DATE, 'DD/MM/YYYY'),
    TARIFF_ID
FROM ext_customers;
COMMIT;


-- -----------------------------------------------------------------------------
-- MONTHLY_STATS: External Table ile CSV okuma
-- -----------------------------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ext_monthly_stats';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_monthly_stats (
    ID             NUMBER(10),
    CUSTOMER_ID    NUMBER(10),
    DATA_USAGE     VARCHAR2(30),
    MINUTE_USAGE   NUMBER(10),
    SMS_USAGE      NUMBER(10),
    PAYMENT_STATUS VARCHAR2(10)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY csv_data_dir
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        CHARACTERSET AL32UTF8
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
        (ID, CUSTOMER_ID, DATA_USAGE, MINUTE_USAGE, SMS_USAGE, PAYMENT_STATUS)
    )
    LOCATION ('MONTHLY_STATS.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO MONTHLY_STATS (ID, CUSTOMER_ID, DATA_USAGE, MINUTE_USAGE, SMS_USAGE, PAYMENT_STATUS)
SELECT
    ID,
    CUSTOMER_ID,
    TO_NUMBER(DATA_USAGE),
    MINUTE_USAGE,
    SMS_USAGE,
    PAYMENT_STATUS
FROM ext_monthly_stats;
COMMIT;


-- -----------------------------------------------------------------------------
-- Gecici external tablolari temizle
-- -----------------------------------------------------------------------------
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ext_customers'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ext_monthly_stats'; EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- -----------------------------------------------------------------------------
-- Istatistikleri guncelle ve dogrulama
-- -----------------------------------------------------------------------------
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TARIFFS');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMERS');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'MONTHLY_STATS');

SELECT 'TARIFFS'       AS TABLO, COUNT(*) AS SATIR FROM TARIFFS
UNION ALL
SELECT 'CUSTOMERS'     AS TABLO, COUNT(*) AS SATIR FROM CUSTOMERS
UNION ALL
SELECT 'MONTHLY_STATS' AS TABLO, COUNT(*) AS SATIR FROM MONTHLY_STATS;
