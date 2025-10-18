
CREATE DATABASE IF NOT EXISTS pandemic;
USE pandemic;

-- Таблиця довідника сутностей
DROP TABLE IF EXISTS entities;
CREATE TABLE entities (
  entity_id   INT AUTO_INCREMENT PRIMARY KEY,
  entity_name VARCHAR(255) NOT NULL,
  code        VARCHAR(50)  NOT NULL,
  UNIQUE KEY uk_entity_code (entity_name, code)
);

-- Основна таблиця даних
DROP TABLE IF EXISTS infectious_data;
CREATE TABLE infectious_data (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  entity_id     INT NOT NULL,
  Year          INT NOT NULL,
  Number_rabies DECIMAL(20,4) NULL,
  FOREIGN KEY fk_infectious_entity (entity_id) REFERENCES entities(entity_id)
);

-- Наповнення довідника
INSERT INTO entities(entity_name, code)
SELECT DISTINCT
  TRIM(`Entity`),
  TRIM(`Code`)
FROM infectious_cases
WHERE TRIM(`Entity`) <> '' AND TRIM(`Code`) <> '';

-- Наповнення даних
INSERT INTO infectious_data(entity_id, Year, Number_rabies)
SELECT
  e.entity_id,
  CAST(NULLIF(TRIM(ic.`Year`), '') AS UNSIGNED),
  CAST(NULLIF(TRIM(ic.`Number_rabies`), '') AS DECIMAL(20,4))
FROM infectious_cases ic
JOIN entities e
  ON e.entity_name = TRIM(ic.`Entity`)
 AND e.code        = TRIM(ic.`Code`);

-- Перевірка кількості записів (вимога ДЗ)
SELECT COUNT(*) AS total_loaded_rows FROM infectious_cases;

-- Аналітика по Number_rabies (відсіяти порожні)
SELECT 
  e.entity_name,
  e.code,
  AVG(d.Number_rabies) AS avg_rabies,
  MIN(d.Number_rabies) AS min_rabies,
  MAX(d.Number_rabies) AS max_rabies,
  SUM(d.Number_rabies) AS sum_rabies
FROM infectious_data d
JOIN entities e ON d.entity_id = e.entity_id
WHERE d.Number_rabies IS NOT NULL
GROUP BY e.entity_name, e.code
ORDER BY avg_rabies DESC
LIMIT 10;

-- Дата і різниця в роках
SELECT
  d.id,
  d.Year,
  STR_TO_DATE(CONCAT(d.Year, '-01-01'), '%Y-%m-%d') AS year_start_date,
  CURDATE() AS today_date,
  TIMESTAMPDIFF(
    YEAR,
    STR_TO_DATE(CONCAT(d.Year, '-01-01'), '%Y-%m-%d'),
    CURDATE()
  ) AS years_difference
FROM infectious_data d
LIMIT 10;

-- Функція різниці в роках
DROP FUNCTION IF EXISTS calc_years_diff;
DELIMITER $$
CREATE FUNCTION calc_years_diff(input_year INT)
RETURNS INT
DETERMINISTIC
BEGIN
  RETURN TIMESTAMPDIFF(
    YEAR,
    STR_TO_DATE(CONCAT(input_year, '-01-01'), '%Y-%m-%d'),
    CURDATE()
  );
END$$
DELIMITER ;

-- Використання функції
SELECT d.id, d.Year, calc_years_diff(d.Year) AS years_difference
FROM infectious_data d
LIMIT 10;

-- (Опц.) Індекси для швидких JOIN/фільтрів
CREATE INDEX ix_entities_code_name ON entities(code, entity_name);
CREATE INDEX ix_infectious_data_entity_year ON infectious_data(entity_id, Year);
