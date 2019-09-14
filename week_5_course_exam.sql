DATABASE UA_DILLARDS;

--------------
-- Question 2
--------------
-- How many distinct skus have the brand “Polo fas”, and are either size “XXL” or “black” in color?

SELECT COUNT(DISTINCT sku)
FROM skuinfo
WHERE brand = 'Polo fas' AND (size = 'XXL' OR color = 'black');
--13623

--------------
-- Question 3
--------------
-- There was one store in the database which had only 11 days in one of its months (in other words, that store/month/year combination only contained 11 days of transaction data). In what city and state was this store located?

SELECT t.store, m.city, m.state 
FROM 
   (SELECT EXTRACT(YEAR from saledate) AS yr, 
   EXTRACT(MONTH from saledate) AS mth,
   store,
   COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
   CASE WHEN yr = 2005 AND mth = 8
   THEN 'exclude'
   ELSE 'include'
   END AS exclude
   FROM trnsact
   WHERE stype = 'P' AND exclude = 'include'
   GROUP BY yr, mth, store
   HAVING num_day = 11) AS t
JOIN store_msa AS m
ON t.store = m.store;

--------------
-- Question 4
--------------
--Which sku number had the greatest increase in total sales revenue from November to December?

SELECT 
sku,
SUM(CASE WHEN T.mth = 11 THEN T.rev_per_mth END) AS rev_nov,
SUM(CASE WHEN T.mth = 12 THEN T.rev_per_mth END) AS rev_dec,
rev_dec - rev_nov AS inc
FROM
   (SELECT sku, 
   EXTRACT(YEAR from saledate) AS yr, 
   EXTRACT(MONTH from saledate) AS mth, 
   SUM(amt) AS rev_per_mth
   FROM trnsact
   WHERE stype = 'P'
   GROUP BY yr, mth, sku) AS T
GROUP BY sku
ORDER BY inc DESC;
--3949538

--------------
-- Question 5
--------------
-- What vendor has the greatest number of distinct skus in the transaction table that do not exist in the skstinfo table? (Remember that vendors are listed as distinct numbers in our data set).

SELECT s.vendor, COUNT(DISTINCT s.sku) as num_skus
FROM trnsact AS t
RIGHT JOIN skuinfo AS s
ON t.sku = s.sku
WHERE t.sku IS NULL
GROUP BY s.vendor
ORDER BY num_skus DESC;
--5715232

--------------
-- Question 6
--------------
-- What is the brand of the sku with the greatest standard deviation in sprice? Only examine skus which have been part of over 100 transactions.

SELECT t.sku, t.sprice, t100.std, skuinfo.brand
FROM 
   (SELECT TOP 1 sku, COUNT(DISTINCT trannum) AS num_trnsact, STDDEV_SAMP(sprice) AS std
   FROM trnsact 
   WHERE stype = 'P'
   GROUP BY sku
   HAVING num_trnsact > 100
   ORDER BY std DESC) AS t100
JOIN trnsact AS t
ON t.sku = t100.sku
JOIN skuinfo
ON skuinfo.sku = t.sku;

--------------
-- Question 7
--------------
--What is the city and state of the store which had the greatest increase in average daily revenue (as defined in Teradata Week 5 Exercise Guide) from November to December?

SELECT m.store, m.city, m.state
FROM 
   (SELECT TOP 1 T.store,
   SUM(CASE WHEN T.mth = 11 THEN T.num_day END) AS num_nov_day,
   SUM(CASE WHEN T.mth = 12 THEN T.num_day END) AS num_dec_day,
   SUM(CASE WHEN T.mth = 11 THEN T.rev_per_mth END) AS rev_nov,
   SUM(CASE WHEN T.mth = 12 THEN T.rev_per_mth END) AS rev_dec,
   rev_nov/num_nov_day AS rev_nov_per_day,
   rev_dec/num_dec_day AS rev_dec_per_day,
   rev_dec_per_day - rev_nov_per_day AS inc
   FROM
      (SELECT EXTRACT(YEAR from saledate) AS yr, 
      EXTRACT(MONTH from saledate) AS mth, 
      store,
      COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
      SUM(amt) AS rev_per_mth,
      CASE WHEN mth IN (11,12)
      THEN 'include'
      END AS include
      FROM trnsact
      WHERE stype = 'P' AND include = 'include'
      GROUP BY yr, mth, store
      HAVING num_day >= 20) AS T
   GROUP BY store
   ORDER BY inc DESC) AS T2
JOIN store_msa AS m
ON T2.store = m.store;
--Metairie, LA

--------------
-- Question 8
--------------
--Compare the average daily revenue of the store with the highest msa_income and the store with the lowest median msa_income (according to the msa_income field). In what city and state were these two stores, and which store had a higher average daily revenue?

--calculate rev per day
SELECT T.store, m.msa_income, m.state, m.city, SUM(rev_per_mth)/SUM(num_day) AS rev_per_day
FROM 
--cleaned data
   (SELECT store,
   EXTRACT(YEAR from saledate) AS yr, 
   EXTRACT(MONTH from saledate) AS mth, 
   COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
   SUM(amt) AS rev_per_mth,
   CASE WHEN yr = 2005 AND mth = 8
   THEN 'exclude'
   ELSE 'include'
   END AS exclude
   FROM trnsact
   WHERE stype = 'P' AND exclude = 'include'
   GROUP BY store, yr, mth
   HAVING num_day >= 20) AS T
--end of cleaned data
JOIN store_msa AS m
ON m.store = T.store
GROUP BY T.store, m.msa_income, m.state, m.city
--end of calc rev_per_day
ORDER BY m.msa_income DESC;

-- The store with the highest median msa_income was in Spanish Fort, AL. It had a lower average daily revenue than the store with the lowest median msa_income, which was in McAllen, TX.

--------------
-- Question 9
--------------

--Divide the msa_income groups up so that msa_incomes between 1 and 20,000 are labeled 'low', msa_incomes between 20,001 and 30,000 are labeled 'med-low', msa_incomes between 30,001 and 40,000 are labeled 'med-high', and msa_incomes between 40,001 and 60,000 are labeled 'high'. Which of these groups has the highest average daily revenue (as defined in Teradata Week 5 Exercise Guide) per store?

--test income group--
SELECT store, msa_income,
CASE 
WHEN (msa_income >= 1 AND msa_income <= 20000) THEN 'low'
WHEN (msa_income > 20000 AND msa_income <= 30000) THEN 'med-low'
WHEN (msa_income > 30000 AND msa_income <= 40000) THEN 'med-high'
WHEN (msa_income > 40000 AND msa_income <= 60000) THEN 'high'
END AS income_group
FROM store_msa;
--end test--

--calculate rev per day
SELECT T.store, m.msa_income, m.state, m.city, SUM(rev_per_mth)/SUM(num_day) AS rev_per_day
FROM 
--cleaned data
   (SELECT store,
   EXTRACT(YEAR from saledate) AS yr, 
   EXTRACT(MONTH from saledate) AS mth, 
   COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
   SUM(amt) AS rev_per_mth,
   CASE WHEN yr = 2005 AND mth = 8
   THEN 'exclude'
   ELSE 'include'
   END AS exclude
   FROM trnsact
   WHERE stype = 'P' AND exclude = 'include'
   GROUP BY store, yr, mth
   HAVING num_day >= 20) AS T
--end of cleaned data
JOIN store_msa AS m
ON m.store = T.store
GROUP BY T.store, m.msa_income, m.state, m.city;
--end of calc rev_per_day

--combine queries

SELECT
CASE 
WHEN (msa_income >= 1 AND msa_income <= 20000) THEN 'low'
WHEN (msa_income > 20000 AND msa_income <= 30000) THEN 'med-low'
WHEN (msa_income > 30000 AND msa_income <= 40000) THEN 'med-high'
WHEN (msa_income > 40000 AND msa_income <= 60000) THEN 'high'
END AS income_group,
SUM(total_rev)/SUM(total_day) AS avg_daily_rev
--I think the answer is missing dividing avg_daily_rev by "COUNT(DISTINCT store)" because the number of stores in each group may be different
FROM
--calculate rev per day
   (SELECT T.store, m.msa_income, SUM(rev_per_mth) AS total_rev, SUM(num_day) AS total_day
   FROM 
   --cleaned data
      (SELECT store,
      EXTRACT(YEAR from saledate) AS yr, 
      EXTRACT(MONTH from saledate) AS mth, 
      COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
      SUM(amt) AS rev_per_mth,
      CASE WHEN yr = 2005 AND mth = 8
      THEN 'exclude'
      ELSE 'include'
      END AS exclude
      FROM trnsact
      WHERE stype = 'P' AND exclude = 'include'
      GROUP BY store, yr, mth
      HAVING num_day >= 20) AS T
      --end of cleaned data
   JOIN store_msa AS m
   ON m.store = T.store
   GROUP BY T.store, m.msa_income) AS T2
   --end of calc rev_per_day
GROUP BY income_group
ORDER BY avg_daily_rev;
--low, 34159.76

--------------
-- Question 10
--------------
--Divide stores up so that stores with msa populations between 1 and 100,000 are labeled 'very small', stores with msa populations between 100,001 and 200,000 are labeled 'small', stores with msa populations between 200,001 and 500,000 are labeled 'med_small', stores with msa populations between 500,001 and 1,000,000 are labeled 'med_large', stores with msa populations between 1,000,001 and 5,000,000 are labeled “large”, and stores with msa_population greater than 5,000,000 are labeled “very large”. What is the average daily revenue (as defined in Teradata Week 5 Exercise Guide) for a store in a “very large” population msa?

SELECT
CASE 
WHEN (msa_pop >= 1 AND msa_pop <= 100000) THEN 'very small'
WHEN (msa_pop > 100000 AND msa_pop <= 200000) THEN 'small'
WHEN (msa_pop > 200000 AND msa_pop <= 500000) THEN 'med_small'
WHEN (msa_pop > 500000 AND msa_pop <= 1000000) THEN 'med_large'
WHEN (msa_pop > 1000000 AND msa_pop <= 5000000) THEN 'large'
WHEN (msa_pop > 5000000) THEN 'very large'
END AS pop_group,
SUM(total_rev)/SUM(total_day) AS avg_daily_rev
--I think the answer is missing dividing avg_daily_rev by "COUNT(DISTINCT store)" because the number of stores in each group may be different
FROM
--calculate rev per day
   (SELECT T.store, m.msa_pop, SUM(rev_per_mth) AS total_rev, SUM(num_day) AS total_day
   FROM 
   --cleaned data
      (SELECT store,
      EXTRACT(YEAR from saledate) AS yr, 
      EXTRACT(MONTH from saledate) AS mth, 
      COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
      SUM(amt) AS rev_per_mth,
      CASE WHEN yr = 2005 AND mth = 8
      THEN 'exclude'
      ELSE 'include'
      END AS exclude
      FROM trnsact
      WHERE stype = 'P' AND exclude = 'include'
      GROUP BY store, yr, mth
      HAVING num_day >= 20) AS T
      --end of cleaned data
   JOIN store_msa AS m
   ON m.store = T.store
   GROUP BY T.store, m.msa_pop) AS T2
   --end of calc rev_per_day
GROUP BY pop_group
ORDER BY avg_daily_rev;
-large 25451.53

--------------
-- Question 11
--------------
--Which department in which store had the greatest percent increase in average daily sales revenue from November to December, and what city and state was that store located in? Only examine departments whose total sales were at least $1,000 in both November and December.

SELECT str.store, str.state, str.city, d.deptdesc,
   SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=11 THEN t.amt END) AS Novsales,
   SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=12 THEN t.amt END) AS Decsales,
   COUNT(DISTINCT CASE WHEN EXTRACT(MONTH from saledate)=11 THEN t.saledate END) AS Novsaldays,
   COUNT(DISTINCT CASE WHEN EXTRACT(MONTH from saledate)=12 THEN t.saledate END) AS Decsaldays,
   Novsales/Novsaldays AS avdailyNovsales, Decsales/Decsaldays AS avdailyDecsales,
   ((avdailyDecsales - avdailyNovsales) / avdailyNovsales*100) AS PerChSales
FROM trnsact t 
JOIN strinfo str ON str.store=t.store
JOIN skuinfo sks ON sks.sku=t.sku
JOIN deptinfo d ON d.dept=sks.dept
--clean data
WHERE t.stype='p' and t.store||EXTRACT(YEAR from t.saledate)||EXTRACT(MONTH from t.saledate) IN
  (SELECT store||EXTRACT(YEAR from saledate)||EXTRACT(MONTH from saledate)
   FROM trnsact
   GROUP BY store, EXTRACT(YEAR from saledate), EXTRACT(MONTH from saledate)
   HAVING COUNT(DISTINCT saledate)>= 20)
--end of cleaning data
GROUP BY str.store, str.city, str.state, d.deptdesc
HAVING Novsales > 1000 AND Decsales > 1000
ORDER BY PerChSales DESC;
--Louisvl department, Salina, KS

--------------
-- Question 12
--------------
--Which department within a particular store had the greatest decrease in average daily sales revenue from August to September, and in what city and state was that store located?

SELECT str.store, str.state, str.city, d.deptdesc, 
CASE WHEN (EXTRACT(YEAR from saledate) = 2005 AND EXTRACT(MONTH from saledate) = 8) THEN 'exclude'
ELSE 'include' END AS exclude,
   SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=8 THEN t.amt END) AS aug_sales,
   SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=9 THEN t.amt END) AS sep_sales,
   COUNT(DISTINCT CASE WHEN EXTRACT(MONTH from saledate)=8 THEN t.saledate END) AS aug_saldays,
   COUNT(DISTINCT CASE WHEN EXTRACT(MONTH from saledate)=9 THEN t.saledate END) AS sep_saldays,
   aug_sales/aug_saldays AS avg_daily_aug_sales, sep_sales/sep_saldays AS avg_daily_sep_sales,
   avg_daily_aug_sales - avg_daily_sep_sales AS decrease
FROM trnsact t 
JOIN strinfo str ON str.store=t.store
JOIN skuinfo sks ON sks.sku=t.sku
JOIN deptinfo d ON d.dept=sks.dept
--clean data
WHERE t.stype='p' AND exclude = 'include' AND t.store||EXTRACT(YEAR from t.saledate)||EXTRACT(MONTH from t.saledate) IN
  (SELECT store||EXTRACT(YEAR from saledate)||EXTRACT(MONTH from saledate)
   FROM trnsact
   GROUP BY store, EXTRACT(YEAR from saledate), EXTRACT(MONTH from saledate)
   HAVING COUNT(DISTINCT saledate)>= 20)
--end of cleaning data
GROUP BY str.store, str.city, str.state, d.deptdesc, exclude
ORDER BY decrease DESC;
--Clinique department, Louisville, KY

--------------
-- Question 13
--------------
--Identify which department, in which city and state of what store, had the greatest DECREASE in the number of items sold from August to September. How many fewer items did that department sell in September compared to August?

SELECT str.store, str.state, str.city, d.deptdesc, 
CASE WHEN (EXTRACT(YEAR from saledate) = 2005 AND EXTRACT(MONTH from saledate) = 8) THEN 'exclude'
ELSE 'include' END AS exclude,
   COUNT(CASE WHEN EXTRACT(MONTH from saledate)=8 THEN t.quantity END) AS aug_num_item,
   COUNT(CASE WHEN EXTRACT(MONTH from saledate)=9 THEN t.quantity END) AS sep_num_item,
   aug_num_item - sep_num_item AS decr_num_item
FROM trnsact t 
JOIN strinfo str ON str.store=t.store
JOIN skuinfo sks ON sks.sku=t.sku
JOIN deptinfo d ON d.dept=sks.dept
--clean data
WHERE t.stype='p' AND exclude = 'include'
--end of cleaning data
GROUP BY str.store, str.city, str.state, d.deptdesc, exclude
ORDER BY decr_num_item DESC;
--Clinique department, Louisville, KY, 13491

--------------
-- Question 14
--------------
--For each store, determine the month with the minimum average daily revenue (as defined in Teradata Week 5 Exercise Guide) . For each of the twelve months of the year, count how many stores' minimum average daily revenue was in that month. During which month(s) did over 100 stores have their minimum average daily revenue?

SELECT T2.mth, COUNT(DISTINCT T2.store)
FROM 
   (SELECT store, rev_per_mth/num_day AS rev_per_day, mth, ROW_NUMBER() OVER (PARTITION BY store ORDER BY rev_per_day ASC)             AS mth_ROWNUM
   FROM
      (SELECT EXTRACT(YEAR from saledate) AS yr, 
      EXTRACT(MONTH from saledate) AS mth,
      store,
      COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
      SUM(amt) AS rev_per_mth,
      CASE WHEN yr = 2005 AND mth = 8
      THEN 'exclude'
      ELSE 'include'
      END AS exclude
      FROM trnsact
      WHERE stype = 'P' AND exclude = 'include'
      GROUP BY yr, mth, store
      HAVING num_day >= 20) AS T
   QUALIFY mth_ROWNUM = 1) AS T2
GROUP BY T2.mth;
--aug, 121

--------------
-- Question 15
--------------
--Write a query that determines the month in which each store had its maximum number of sku units returned. During which month did the greatest number of stores have their maximum number of sku units returned?


SELECT T2.mth, COUNT(DISTINCT T2.store)
FROM 
   (SELECT store, mth, ROW_NUMBER() OVER (PARTITION BY store ORDER BY num_sku DESC) AS mth_ROWNUM
   FROM
      (SELECT EXTRACT(YEAR from saledate) AS yr, 
      EXTRACT(MONTH from saledate) AS mth,
      store,
      COUNT(DISTINCT EXTRACT(DAY from saledate)) AS num_day,
      COUNT(DISTINCT sku) AS num_sku,
      CASE WHEN yr = 2005 AND mth = 8
      THEN 'exclude'
      ELSE 'include'
      END AS exclude
      FROM trnsact
      WHERE stype = 'R' AND exclude = 'include'
      GROUP BY yr, mth, store
      HAVING num_day >= 20) AS T
   QUALIFY mth_ROWNUM = 1) AS T2
GROUP BY T2.mth;
-- Dec, 293
