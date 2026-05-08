-- =============================================================================
-- INIT SCRIPT 1/2 — TABLO VE INDEX OLUSTURMA
-- Bu script docker-compose basladiginda otomatik calisir.
-- TABLE_CREATION_SCRIPTS.sql ile icerigi ayni olup container ortami icin
-- CSV dizin izinleri de bu scripte dahildir.
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Mevcut tablolari temizle
BEGIN EXECUTE IMMEDIATE 'DROP TABLE MONTHLY_STATS CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CUSTOMERS CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE TARIFFS CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- External table yuklemesi icin dizin nesnesini olustur
CREATE OR REPLACE DIRECTORY csv_data_dir AS '/opt/oracle/data';
GRANT READ ON DIRECTORY csv_data_dir TO PUBLIC;
GRANT READ ON DIRECTORY csv_data_dir TO telco;

-- TARIFFS tablosu
CREATE TABLE TARIFFS (
    TARIFF_ID    NUMBER(10)         NOT NULL,
    NAME         VARCHAR2(100 CHAR) NOT NULL,
    MONTHLY_FEE  NUMBER(10, 2)      NOT NULL,
    DATA_LIMIT   NUMBER(15, 2)      NOT NULL,
    MINUTE_LIMIT NUMBER(10)         NOT NULL,
    SMS_LIMIT    NUMBER(10)         NOT NULL,
    CONSTRAINT pk_tariffs PRIMARY KEY (TARIFF_ID),
    CONSTRAINT chk_tariff_fee    CHECK (MONTHLY_FEE  >= 0),
    CONSTRAINT chk_data_limit    CHECK (DATA_LIMIT   >= 0),
    CONSTRAINT chk_minute_limit  CHECK (MINUTE_LIMIT >= 0),
    CONSTRAINT chk_sms_limit     CHECK (SMS_LIMIT    >= 0)
);

-- CUSTOMERS tablosu
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID NUMBER(10)         NOT NULL,
    NAME        VARCHAR2(200 CHAR) NOT NULL,
    CITY        VARCHAR2(100 CHAR) NOT NULL,
    SIGNUP_DATE DATE               NOT NULL,
    TARIFF_ID   NUMBER(10)         NOT NULL,
    CONSTRAINT pk_customers         PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT fk_customers_tariff  FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS (TARIFF_ID)
);

-- MONTHLY_STATS tablosu
CREATE TABLE MONTHLY_STATS (
    ID             NUMBER(10)    NOT NULL,
    CUSTOMER_ID    NUMBER(10)    NOT NULL,
    DATA_USAGE     NUMBER(15, 2) NOT NULL,
    MINUTE_USAGE   NUMBER(10)    NOT NULL,
    SMS_USAGE      NUMBER(10)    NOT NULL,
    PAYMENT_STATUS VARCHAR2(10)  NOT NULL,
    CONSTRAINT pk_monthly_stats     PRIMARY KEY (ID),
    CONSTRAINT fk_ms_customer       FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    CONSTRAINT chk_payment_status   CHECK (PAYMENT_STATUS IN ('PAID', 'LATE', 'UNPAID')),
    CONSTRAINT chk_data_usage       CHECK (DATA_USAGE   >= 0),
    CONSTRAINT chk_minute_usage     CHECK (MINUTE_USAGE >= 0),
    CONSTRAINT chk_sms_usage        CHECK (SMS_USAGE    >= 0)
);

-- Indexler
CREATE INDEX idx_customers_tariff  ON CUSTOMERS     (TARIFF_ID);
CREATE INDEX idx_customers_signup  ON CUSTOMERS     (SIGNUP_DATE);
CREATE INDEX idx_customers_city    ON CUSTOMERS     (CITY);
CREATE INDEX idx_ms_customer       ON MONTHLY_STATS (CUSTOMER_ID);
CREATE INDEX idx_ms_payment        ON MONTHLY_STATS (PAYMENT_STATUS);
