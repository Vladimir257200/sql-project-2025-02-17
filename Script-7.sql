

                                      -- Projekt z SQL 2025-02-17

-- Otázka č.1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
			


SELECT *
FROM  czechia_payroll_industry_branch cpib;    --použité tabulky

SELECT * 
FROM czechia_payroll cp;                       --použité tabulky


SELECT name,                                   --řešení
	   payroll_year, 
	   salary_growth
FROM Payroll_Changes
WHERE salary_growth < 0;

SELECT name, 
	  MIN(salary_growth) AS worst_yearly_growth 	
FROM Payroll_Changes
GROUP BY name
ORDER BY worst_yearly_growth ASC
LIMIT 1;



--Otázka 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

--Vytvoření pohledu pro průměrné mzdy v prvním a posledním roce

CREATE VIEW Average_Salary AS
SELECT 
    payroll_year, 
    AVG(value) AS avg_salary
FROM czechia_payroll
GROUP BY payroll_year;

-- Vytvoření pohledu pro ceny mléka a chleba v jednotlivých letech

CREATE VIEW Milk_Bread_Prices AS
SELECT 
    cp.date_from, 
    MAX(CASE WHEN cpc.name = 'Milk' THEN cpc.price_value END) AS milk_price,
    MAX(CASE WHEN cpc.name = 'Bread' THEN cpc.price_value END) AS bread_price
FROM czechia_price cp
JOIN czechia_price_category cpc 
    ON cp.category_code = cpc.code
GROUP BY cp.date_from;

-- Vypočítáme, kolik litrů mléka a kg chleba bylo možné koupit za průměrnou mzdu v prvním a posledním roce

SELECT 
    ms.payroll_year, 
    ms.avg_salary, 
    mp.milk_price, 
    mp.bread_price, 
    (ms.avg_salary / mp.milk_price) AS liters_of_milk, 
    (ms.avg_salary / mp.bread_price) AS kg_of_bread
FROM Average_Salary ms
JOIN Milk_Bread_Prices mp 
    ON ms.payroll_year = mp.date_from
WHERE ms.payroll_year IN (
    (SELECT MIN(payroll_year) FROM Average_Salary), 
    (SELECT MAX(payroll_year) FROM Average_Salary)
)
ORDER BY ms.payroll_year;

--Vytvoření pohledu pro meziroční růst cen potravin

CREATE VIEW Food_Price_Growth AS
SELECT 
    cpc.name, 
    cp.payroll_year, 
    AVG(cp.value) AS avg_price, 
    LAG(AVG(cp.value)) OVER (PARTITION BY cpc.name ORDER BY cp.year) AS prev_year_price,
    ((AVG(cp.value) - LAG(AVG(cp.value)) OVER (PARTITION BY cpc.name ORDER BY cp.payroll_year)) 
    / LAG(AVG(cp.value)) OVER (PARTITION BY cpc.category_name ORDER BY cp.payroll_year)) * 100 AS price_growth
FROM czechia_price cp
JOIN czechia_price_category cpc 
    ON cp.category_code = cpc.code
GROUP BY cpc.name, cp.payroll_year;

-- Vyhledání kategorie s nejnižším meziročním růstem cen

SELECT name, AVG(price_growth) AS avg_growth
FROM Food_Price_Growth
GROUP BY name
ORDER BY avg_growth ASC
LIMIT 1;

--porovnání růstu mezd a potravin, které rostly rycleji

SELECT fpg.year, 
       AVG(fpg.price_growth) AS avg_food_growth, 
       (ms.avg_salary - LAG(ms.avg_salary) OVER (ORDER BY ms.payroll_year)) / LAG(ms.avg_salary) OVER (ORDER BY ms.payroll_year) * 100 AS salary_growth
FROM Food_Price_Growth fpg
JOIN Average_Salary ms ON fpg.year = ms.payroll_year 
GROUP BY fpg.year, ms.avg_salary;



-- Otázka 3. Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
	
	
--Vytvoření pohledu pro meziroční růst cen potravin

SELECT *
FROM czechia_price_category cpc; 

CREATE VIEW Price_Changes AS
SELECT 
    cpc.name, 
    cp.date_from, 
    AVG(cp.value) AS avg_price, 
    LAG(AVG(cp.value)) OVER (PARTITION BY cp.category_code ORDER BY cp.date_from) AS prev_year_price,
    ((AVG(cp.value) - LAG(AVG(cp.value)) OVER (PARTITION BY cp.category_code ORDER BY cp.date_from)) 
    / LAG(AVG(cp.value)) OVER (PARTITION BY cp.category_code ORDER BY cp.date_from)) * 100 AS price_growth
FROM czechia_price cp
JOIN czechia_price_category cpc 
    ON cp.category_code = cpc.code
GROUP BY cpc.name, cp.category_code, cp.date_from;

SELECT *
FROM price_changes pc 


--Dotaz na kategorii s nejnižším meziročním růstem cen

SELECT name, AVG(price_growth) AS avg_price_growth
FROM Price_Changes
WHERE price_growth IS NOT NULL  -- Vyhneme se NULL hodnotám
GROUP BY name
ORDER BY avg_price_growth ASC
LIMIT 1;
	
	
--Otázka 4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?	

--Vytvoření pohledu pro průměrné mzdy podle roku

CREATE VIEW Average_Salary AS
SELECT 
    payroll_year, 
    AVG(value) AS avg_salary
FROM czechia_payroll
GROUP BY payroll_year;

--Vytvoření pohledu pro meziroční růst mezd

CREATE VIEW Salary_Growth AS
SELECT 
    payroll_year, 
    avg_salary, 
    LAG(avg_salary) OVER (ORDER BY payroll_year) AS prev_year_salary,
    ((avg_salary - LAG(avg_salary) OVER (ORDER BY payroll_year)) 
    / LAG(avg_salary) OVER (ORDER BY payroll_year)) * 100 AS salary_growth
FROM Average_Salary;

--Vytvoření pohledu pro meziroční růst cen potravin

CREATE VIEW Food_Price_Growth AS
SELECT 
    cp.date_from, 
    AVG(cp.value) AS avg_price, 
    LAG(AVG(cp.value)) OVER (ORDER BY cp.date_from) AS prev_year_price,
    ((AVG(cp.value) - LAG(AVG(cp.value)) OVER (ORDER BY cp.date_from)) 
    / LAG(AVG(cp.value)) OVER (ORDER BY cp.date_from)) * 100 AS price_growth
FROM czechia_price cp
GROUP BY cp.date_from;

--Najdeme roky, kdy růst cen potravin byl o více než 10 % vyšší než růst mezd

SELECT 
    fpg.date_from, 
    fpg.price_growth, 
    sg.salary_growth,
    (fpg.price_growth - sg.salary_growth) AS difference
FROM Food_Price_Growth fpg
JOIN Salary_Growth sg ON fpg.date_from = sg.payroll_year
WHERE (fpg.price_growth - sg.salary_growth) > 10
ORDER BY difference DESC;

	
--Otázka 5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, 	
		--  projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?	

--Vytvoření pohledu pro meziroční růst HDP

CREATE VIEW GDP_Growth AS
SELECT 
    year, 
    gdp, 
    LAG(gdp) OVER (ORDER BY year) AS prev_year_gdp,
    ((gdp - LAG(gdp) OVER (ORDER BY year)) / LAG(gdp) OVER (ORDER BY year)) * 100 AS gdp_growth
FROM economies
WHERE country = 'Czech Republic';

--Vytvoření pohledu pro meziroční růst mezd

CREATE VIEW Salary_Growth AS
SELECT 
    payroll_year, 
    AVG(value) AS avg_salary, 
    LAG(AVG(value)) OVER (ORDER BY payroll_year) AS prev_year_salary,
    ((AVG(value) - LAG(AVG(value)) OVER (ORDER BY payroll_year)) / LAG(AVG(value)) OVER (ORDER BY payroll_year)) * 100 AS salary_growth
FROM czechia_payroll
GROUP BY payroll_year;

--Vytvoření pohledu pro meziroční růst cen potravin

CREATE VIEW Food_Price_Growth AS
SELECT 
    date_from, 
    AVG(value) AS avg_price, 
    LAG(AVG(value)) OVER (ORDER BY date_from) AS prev_year_price,
    ((AVG(value) - LAG(AVG(value)) OVER (ORDER BY date_from)) / LAG(AVG(value)) OVER (ORDER BY date_from)) * 100 AS price_growth
FROM czechia_price
GROUP BY date_from;

--Spojení dat a analýza vlivu HDP na mzdy a ceny potravin

SELECT 
    gdpg.year, 
    gdpg.gdp_growth, 
    sg.salary_growth, 
    fpg.price_growth,
    LAG(gdpg.gdp_growth) OVER (ORDER BY gdpg.year) AS prev_year_gdp_growth,
    (sg.salary_growth - LAG(gdpg.gdp_growth) OVER (ORDER BY gdpg.year)) AS salary_vs_gdp,
    (fpg.price_growth - LAG(gdpg.gdp_growth) OVER (ORDER BY gdpg.year)) AS price_vs_gdp
FROM GDP_Growth gdpg
LEFT JOIN Salary_Growth sg ON gdpg.year = sg.payroll_year
LEFT JOIN Food_Price_Growth fpg ON gdpg.year = fpg.date_from
ORDER BY gdpg.year;

--Ve kterých odvětvých mzdy rostly nejvíce 
SELECT 
    cpib.name, 
    sg.payroll_year, 
    sg.salary_growth
FROM Salary_Growth sg
JOIN czechia_payroll_industry_branch cpib ON sg.payroll_year = cpib.name 
ORDER BY sg.salary_growth DESC;


-- 1. Vytvoření primární tabulky pro Českou republiku


CREATE TABLE t_{vladimir}_{bittner}_project_SQL_primary_final AS
SELECT 
    p.date_from, 
    p.category_code, 
    f.name,
    p.price_value AS food_price,
    pr.industry_branch_code, 
    ib.name,
    pr.value AS avg_salary
FROM czechia_price p
JOIN czechia_price_category f ON p.category_code = f.code
JOIN czechia_payroll pr ON p.category_code = pr.payroll_year
JOIN czechia_payroll_industry_branch ib ON pr.industry_branch_code = ib.code
WHERE p.region_code IS NULL AND pr.region_code IS NULL;

-- Pouze celorepubliková data




-- 2. Vytvoření sekundární tabulky pro mezinárodní srovnání


CREATE TABLE t_{vladimir}_{bittner}_project_SQL_secondary_final AS
SELECT 
    e.year, 
    e.country, 
    c.country, 
    e.gdp, 
    e.gini, 
    e.taxes
FROM economies e
JOIN countries c ON e.country = c.country
WHERE c.continent = 'Europe'; 

-- Filtrovat pouze evropské státy



		 
	
	
	
	
























	
	
	
	
	
	
	
	
	
	
































