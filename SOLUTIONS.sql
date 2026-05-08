-- =============================================================================
-- TELCO DATABASE - SOLUTIONS
-- Developer: Staj Adayi | Database: Oracle XE 21c
-- =============================================================================
-- Bu dosya, README'de tanimlanan 6 kategorideki analitik sorguları icerir.
-- Her sorgu, yaklasimi aciklayan en az 3 cumle yorum ile belgelenmistir.
-- Sorgular TABLE_CREATION_SCRIPTS.sql ile olusturulan sema uzerinde calisir.
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';


-- =============================================================================
-- KATEGORI 1 — TARIFE BAZLI MUSTERI SORGULARI
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 Kobiye Destek Tarifesindeki Musteriler
-- -----------------------------------------------------------------------------
-- Bu sorgu, "Kobiye Destek" tarifesine abone olan tum musterileri listeler.
-- Tarife bilgisine isim uzerinden erismek icin CUSTOMERS ile TARIFFS tablolari
-- TARIFF_ID foreign key'i uzerinden JOIN edilmistir. Boylece tarife ID'si
-- hardcoded yazilmadan tarife ismi degistigi durumda sorgu hala calismaya devam eder.
-- Sonuclar kayit tarihine gore sirali sunularak en eski aboneden yeniye
-- kronolojik bir bakis imkani saglanmistir.

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.SIGNUP_DATE;


-- -----------------------------------------------------------------------------
-- 1.2 Kobiye Destek'e En Son Abone Olan Musteri
-- -----------------------------------------------------------------------------
-- Bu sorgu, "Kobiye Destek" tarifesine en gec abone olan musterinin bilgilerini
-- dondurur. Ic sorgu, bu tarifedeki en buyuk SIGNUP_DATE degerini bulur; dis
-- sorgu ise bu tarihe esit kayitlari getirir. Ayni tarihte birden fazla musteri
-- abone olmus olabilecegi dusunulerek tek satir dondurmek yerine esit tarihlerin
-- tamami listelenir; bu sekilde veri kaybinin onune gecilmistir.

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
  AND c.SIGNUP_DATE = (
      SELECT MAX(c2.SIGNUP_DATE)
      FROM CUSTOMERS c2
      JOIN TARIFFS t2 ON c2.TARIFF_ID = t2.TARIFF_ID
      WHERE t2.NAME = 'Kobiye Destek'
  );


-- =============================================================================
-- KATEGORI 2 — TARIFE DAGILIMI
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 Tarifelere Gore Musteri Sayisi Dagilimi
-- -----------------------------------------------------------------------------
-- Bu sorgu, her tarifenin kac musterisi oldugunu ve toplam musteri sayisi
-- icerisindeki yuzde payini hesaplar. Pencere fonksiyonu (SUM OVER()) kullanilarak
-- GROUP BY'i bozmadan toplam musteri sayisina erisim saglanmis ve tek sorguda
-- hem mutlak sayi hem de oran goruntulenmistir. Sonuclar musteri sayisina gore
-- azalan sirayla sunularak en populer tarifeler kolayca gorulur.

SELECT
    t.NAME                                                        AS TARIFE_ADI,
    COUNT(c.CUSTOMER_ID)                                          AS MUSTERI_SAYISI,
    ROUND(
        COUNT(c.CUSTOMER_ID) * 100.0
        / SUM(COUNT(c.CUSTOMER_ID)) OVER (),
    2)                                                            AS YUZDE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
GROUP BY t.NAME
ORDER BY MUSTERI_SAYISI DESC;


-- =============================================================================
-- KATEGORI 3 — EN ERKEN KAYIT ANALIZI
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 En Erken Kayit Olan Musteriler
-- -----------------------------------------------------------------------------
-- README'de ozellikle belirtildigi gibi "en erken musteri" kavramı musteri ID'si
-- ile degil, SIGNUP_DATE alanindaki en kucuk tarih degeri ile belirlenmektedir.
-- Bu nedenle ic sorgu MIN(SIGNUP_DATE) ile sistemdeki ilk kayit tarihini bulur;
-- dis sorgu ise bu tarihe sahip tum musterileri dondurur. Ayni gun birden fazla
-- musteri kayit olmus olabileceginden WHERE ile filtreleme yaklasimi,
-- yalnizca ilk satiri alan ROWNUM yontemine kiyasla daha dogru sonuc uretir.

SELECT
    CUSTOMER_ID,
    NAME,
    CITY,
    SIGNUP_DATE,
    TARIFF_ID
FROM CUSTOMERS
WHERE SIGNUP_DATE = (
    SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS
)
ORDER BY CUSTOMER_ID;


-- -----------------------------------------------------------------------------
-- 3.2 En Erken Kayit Olan Musterilerin Sehir Dagilimi
-- -----------------------------------------------------------------------------
-- Bu sorgu, 3.1'deki en erken kayit tarihine sahip musterilerin hangi sehirlerden
-- geldigini ve her sehirden kac musteri oldugunu gosterir. Isletme acisından hangi
-- cografyanin ilk abonelere kaynak oldugu anlasılabilir. Sonuclar musteri sayisina
-- gore azalan sirayla sunularak en yoğun sehirler kolayca tespit edilir.

SELECT
    CITY                    AS SEHIR,
    COUNT(*) AS MUSTERI_SAYISI
FROM CUSTOMERS
WHERE SIGNUP_DATE = (
    SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS
)
GROUP BY CITY
ORDER BY MUSTERI_SAYISI DESC;


-- =============================================================================
-- KATEGORI 4 — EKSIK AYLIK KAYIT ANALIZI
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1 Aylik Istatistik Kaydi Bulunmayan Musteriler
-- -----------------------------------------------------------------------------
-- Bu sorgu, CUSTOMERS tablosunda var olan ancak MONTHLY_STATS tablosunda hic
-- kaydi bulunmayan musterileri tespit eder. NOT IN alt sorgusu MONTHLY_STATS'tan
-- mevcut tum musteri ID'lerini toplayarak CUSTOMERS tablosuyla karsilastirir.
-- NOT IN ile NOT EXISTS secenekleri icerisinde NOT IN yontemi, kucuk ve orta
-- olcekli verilerde okunabilirlik acisindan tercih edilmistir; ancak NULL
-- degerleri iceren durumlarda NOT EXISTS daha guvenlidir (bu veride NULL yok).
-- Boyle musterilerin varligı veri eklemesindeki hataya isaret etmektedir.

SELECT
    CUSTOMER_ID,
    NAME,
    CITY,
    SIGNUP_DATE,
    TARIFF_ID
FROM CUSTOMERS
WHERE CUSTOMER_ID NOT IN (
    SELECT DISTINCT CUSTOMER_ID FROM MONTHLY_STATS
)
ORDER BY CUSTOMER_ID;


-- -----------------------------------------------------------------------------
-- 4.2 Kaydi Eksik Musterilerin Sehir Dagilimi
-- -----------------------------------------------------------------------------
-- Bu sorgu, aylik istatistik kaydi bulunmayan musterilerin hangi sehirlerde
-- yogunlastıgını gosterir. Veri ekleme hatasinin belirli bir bolgeyle iliskili
-- olup olmadigi bu analiz ile anlasilabilir. Sehir bazli gruplama ve sayım,
-- hata paterni hakkinda anlamlı bir ozet sunar.

SELECT
    c.CITY           AS SEHIR,
    COUNT(*) AS EKSIK_MUSTERI
FROM CUSTOMERS c
WHERE c.CUSTOMER_ID NOT IN (
    SELECT DISTINCT CUSTOMER_ID FROM MONTHLY_STATS
)
GROUP BY c.CITY
ORDER BY EKSIK_MUSTERI DESC;


-- =============================================================================
-- KATEGORI 5 — KULLANIM ANALIZI
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5.1 Veri Limitinin En Az %75'ini Kullanan Musteriler
-- -----------------------------------------------------------------------------
-- Bu sorgu, aylık veri kullaniminin tarifede tanimlanan limitin yuzde 75'ine
-- ulasan veya asan musterileri listeler. DATA_LIMIT = 0 olan tarifelerde veri
-- sinirsiz oldugu icin bu musteriler karsilastirma disinda birakilmistir; aksi
-- halde sifira bolme hatasi ya da yaniltici sonuclar ortaya cikabilirdi.
-- Her musterinin tarife limitiyle birlikte kullanim miktari da gosterilir,
-- boylece sonuclarin ne kadar "limitine yakin" oldugu izlenebilir.

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    t.NAME                                                      AS TARIFE_ADI,
    ms.DATA_USAGE                                               AS KULLANILAN_MB,
    t.DATA_LIMIT                                                AS LIMIT_MB,
    ROUND(ms.DATA_USAGE * 100.0 / t.DATA_LIMIT, 2)             AS KULLANIM_YUZDESI
FROM CUSTOMERS c
JOIN TARIFFS t       ON c.TARIFF_ID  = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE t.DATA_LIMIT > 0
  AND ms.DATA_USAGE >= 0.75 * t.DATA_LIMIT
ORDER BY KULLANIM_YUZDESI DESC;


-- -----------------------------------------------------------------------------
-- 5.2 Tum Paket Limitlerini Kullanan Musteriler
-- -----------------------------------------------------------------------------
-- Bu sorgu, hem veri hem dakika hem de SMS limitlerini tamamen tuketen musterileri
-- bulur. Tarifelerde DATA_LIMIT veya MINUTE_LIMIT degerinin 0 olmasi "sinirsiz"
-- anlamina geldiginden (Kurumsal SMS tarifesi gibi), 0 degerli limitler kosuldan
-- hariç tutularak yanlis eslesme engellenmistir. Tum ucunu birden bitiren
-- musteriler, paket yukseltmesi veya ek kota satisi icin oncelikli hedef
-- musteri segmentini olusturmaktadir.

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME           AS TARIFE_ADI,
    ms.DATA_USAGE    AS KULLANILAN_VERI_MB,
    ms.MINUTE_USAGE  AS KULLANILAN_DAKIKA,
    ms.SMS_USAGE     AS KULLANILAN_SMS
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID  = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE
    -- Veri limiti: sinirsiz (0) ise atla; aksi halde limit asim kontrolu yap
    (t.DATA_LIMIT   = 0 OR ms.DATA_USAGE   >= t.DATA_LIMIT)
    -- Dakika limiti: sinirsiz (0) ise atla; aksi halde limit asim kontrolu yap
AND (t.MINUTE_LIMIT = 0 OR ms.MINUTE_USAGE >= t.MINUTE_LIMIT)
    -- SMS limiti: sinirsiz (0) ise atla; aksi halde limit asim kontrolu yap
AND (t.SMS_LIMIT    = 0 OR ms.SMS_USAGE    >= t.SMS_LIMIT)
    -- Uclimiti de 0 olan tarife yok, ancak gelecek veri degisikligine karsi
    -- tamamen sinirsiz tarifeler sonuc kumesinden cikarilir
AND NOT (t.DATA_LIMIT = 0 AND t.MINUTE_LIMIT = 0 AND t.SMS_LIMIT = 0)
ORDER BY c.CUSTOMER_ID;


-- =============================================================================
-- KATEGORI 6 — ODEME ANALIZI
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 6.1 Odenmemis Faturasi Olan Musteriler
-- -----------------------------------------------------------------------------
-- Bu sorgu, PAYMENT_STATUS degeri 'UNPAID' olan tum kayitlari ve ilgili musteri
-- bilgilerini dondurur. Musteri adi, sehri ve tarifeye ek olarak aylik ucret
-- de gosterilmekte; bu sayede alacak takibi ve mudahale onceliklendirmesi
-- tek bir sorguda mumkun olmaktadir. Uygulama acisından bu listedeki musteriler
-- otomatik odeme hatirlatma veya kota kısıtlama sistemine girdi olabilir.

SELECT
    c.CUSTOMER_ID,
    c.NAME          AS MUSTERI_ADI,
    c.CITY          AS SEHIR,
    t.NAME          AS TARIFE_ADI,
    t.MONTHLY_FEE   AS AYLIK_UCRET
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID  = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE ms.PAYMENT_STATUS = 'UNPAID'
ORDER BY t.MONTHLY_FEE DESC, c.CUSTOMER_ID;


-- -----------------------------------------------------------------------------
-- 6.2 Tarifeye Gore Odeme Durumu Dagilimi
-- -----------------------------------------------------------------------------
-- Bu sorgu, hangi tarifeye abone olan musterilerin ne oranda odeme yaptigini,
-- gec odedigini ya da odeme yapmadıgini gosterir. Uclu gruplama (tarife + odeme
-- durumu + sayi) ile tarife bazli finansal saglik profili cıkarılabilir. Ornegin
-- belirli bir tarifedeki UNPAID yogunlugu, fiyatlandirma sorununa ya da hedef
-- musteri kitlesinin odeme davranisina isaret edebilir.

SELECT
    t.NAME           AS TARIFE_ADI,
    ms.PAYMENT_STATUS AS ODEME_DURUMU,
    COUNT(*)          AS KAYIT_SAYISI,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY t.NAME),
    2)               AS TARIFE_ICI_YUZDE
FROM MONTHLY_STATS ms
JOIN CUSTOMERS c ON ms.CUSTOMER_ID = c.CUSTOMER_ID
JOIN TARIFFS t   ON c.TARIFF_ID   = t.TARIFF_ID
GROUP BY t.NAME, ms.PAYMENT_STATUS
ORDER BY t.NAME, ms.PAYMENT_STATUS;


-- =============================================================================
-- DOGRULAMA SORGULARI
-- =============================================================================
-- Asagidaki sorgular veri importu ve tablo butunlugunu dogrulamak icindir.

SELECT 'TARIFFS'      AS TABLO, COUNT(*) AS SATIR_SAYISI FROM TARIFFS
UNION ALL
SELECT 'CUSTOMERS'    AS TABLO, COUNT(*) AS SATIR_SAYISI FROM CUSTOMERS
UNION ALL
SELECT 'MONTHLY_STATS' AS TABLO, COUNT(*) AS SATIR_SAYISI FROM MONTHLY_STATS;
