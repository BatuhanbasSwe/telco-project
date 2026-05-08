-- =============================================================================
-- TELCO DATABASE - TABLE CREATION SCRIPTS
-- Developer: Staj Adayi | Database: Oracle XE 21c
-- =============================================================================
-- Bu script, telekom musterileri, tarifeler ve aylik istatistikler icin
-- Oracle XE veritabaninda tablolari olusturur. Yabanci anahtar kisitlamalari,
-- CHECK kısıtlamaları ve performans icin optimum index yapisi dahildir.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. NLS Ayarlari (tarih formati icin)
-- -----------------------------------------------------------------------------
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';


-- -----------------------------------------------------------------------------
-- 2. Mevcut tablolari temizle (yeniden olusturma icin)
-- Tablolar yoksa hata verir, Skip all ile gecebilirsiniz.
-- -----------------------------------------------------------------------------
DROP TABLE MONTHLY_STATS CASCADE CONSTRAINTS PURGE;
DROP TABLE CUSTOMERS CASCADE CONSTRAINTS PURGE;
DROP TABLE TARIFFS CASCADE CONSTRAINTS PURGE;


-- -----------------------------------------------------------------------------
-- 3. TARIFFS Tablosu
-- -----------------------------------------------------------------------------
-- Tum tarifeler bu tabloda tutulur. DATA_LIMIT ve MINUTE_LIMIT degerinin
-- 0 olmasi sinirsiz kullanim anlamina gelir (ornegin Kurumsal SMS tarifesi).
-- MONTHLY_FEE alani icin decimal hassasiyet ileride fiyat degisikliklerine
-- esneklik saglar.
-- -----------------------------------------------------------------------------
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


-- -----------------------------------------------------------------------------
-- 4. CUSTOMERS Tablosu
-- -----------------------------------------------------------------------------
-- Her musterinin kayit tarihi, bulundugu sehir ve bagli oldugu tarife
-- bilgisi bu tabloda saklanir. TARIFF_ID referansi ile TARIFFS tablosuna
-- bagli olup referential integrity saglanmistir. VARCHAR2 CHAR semantigi
-- kullanilarak cok baytli Turkce karakterler dogru bicimde islenir.
-- -----------------------------------------------------------------------------
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID NUMBER(10)         NOT NULL,
    NAME        VARCHAR2(200 CHAR) NOT NULL,
    CITY        VARCHAR2(100 CHAR) NOT NULL,
    SIGNUP_DATE DATE               NOT NULL,
    TARIFF_ID   NUMBER(10)         NOT NULL,
    CONSTRAINT pk_customers PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT fk_customers_tariff
        FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS (TARIFF_ID)
);


-- -----------------------------------------------------------------------------
-- 5. MONTHLY_STATS Tablosu
-- -----------------------------------------------------------------------------
-- Her musterinin aylik veri, dakika, SMS kullanimi ve odeme durumu burada
-- saklanir. DATA_USAGE ondalik deger icerebilir (ornegin 18420.61 MB).
-- PAYMENT_STATUS icin CHECK kisiti yalnizca gecerli degerlere izin verir.
-- CUSTOMER_ID ile CUSTOMERS arasinda zorunlu yabanci anahtar iliskisi vardir,
-- ancak bazi musterilerin kaydi eksik olabilir (veri kalite sorunu).
-- -----------------------------------------------------------------------------
CREATE TABLE MONTHLY_STATS (
    ID             NUMBER(10)    NOT NULL,
    CUSTOMER_ID    NUMBER(10)    NOT NULL,
    DATA_USAGE     NUMBER(15, 2) NOT NULL,
    MINUTE_USAGE   NUMBER(10)    NOT NULL,
    SMS_USAGE      NUMBER(10)    NOT NULL,
    PAYMENT_STATUS VARCHAR2(10)  NOT NULL,
    CONSTRAINT pk_monthly_stats   PRIMARY KEY (ID),
    CONSTRAINT fk_ms_customer     FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    CONSTRAINT chk_payment_status CHECK (PAYMENT_STATUS IN ('PAID', 'LATE', 'UNPAID')),
    CONSTRAINT chk_data_usage     CHECK (DATA_USAGE   >= 0),
    CONSTRAINT chk_minute_usage   CHECK (MINUTE_USAGE >= 0),
    CONSTRAINT chk_sms_usage      CHECK (SMS_USAGE    >= 0)
);


-- -----------------------------------------------------------------------------
-- 6. Index Tanimlari
-- -----------------------------------------------------------------------------
-- JOIN operasyonlarini hizlandirmak icin yabanci anahtar sutunlari indexlendi.
-- SIGNUP_DATE indexi tarih bazli siralama ve filtreleme sorgularini hizlandirir.
-- CITY indexi sehir bazli gruplama sorgularinda tam tablo taramasini engeller.
-- PAYMENT_STATUS indexi odeme durumu filtrelemelerini optimize eder.

CREATE INDEX idx_customers_tariff  ON CUSTOMERS     (TARIFF_ID);
CREATE INDEX idx_customers_signup  ON CUSTOMERS     (SIGNUP_DATE);
CREATE INDEX idx_customers_city    ON CUSTOMERS     (CITY);
CREATE INDEX idx_ms_customer       ON MONTHLY_STATS (CUSTOMER_ID);
CREATE INDEX idx_ms_payment        ON MONTHLY_STATS (PAYMENT_STATUS);


-- -----------------------------------------------------------------------------
-- 7. Dogrulama
-- -----------------------------------------------------------------------------
SELECT TABLE_NAME
FROM USER_TABLES
WHERE TABLE_NAME IN ('TARIFFS', 'CUSTOMERS', 'MONTHLY_STATS')
ORDER BY TABLE_NAME;

SELECT INDEX_NAME, TABLE_NAME, STATUS
FROM USER_INDEXES
WHERE TABLE_NAME IN ('TARIFFS', 'CUSTOMERS', 'MONTHLY_STATS')
ORDER BY TABLE_NAME, INDEX_NAME;
