-- DATA CLEANING - LAYOFFS DATASET

-- Steps:
-- 1. Create staging tables (backup raw data)
-- 2. Remove duplicates
-- 3. Standardize data (trim, format fixes)
-- 4. Handle null/missing values
-- 5. Remove unnecessary rows/columns
-- 6. Final verification


-- STEP 1: EXAMINE RAW DATA
SELECT *
FROM layoffs;

-- STEP 2: CREATE STAGING TABLES
-- Create backup of raw data (never touch original)
CREATE TABLE layoffs_staging
LIKE layoffs;

SELECT *
FROM layoffs_staging;

-- Insert raw data into staging table
INSERT layoffs_staging
SELECT *
FROM layoffs;

-- STEP 3: IDENTIFY AND REMOVE DUPLICATES
-- Check for duplicates using window function
SELECT *,
ROW_NUMBER() OVER(
  PARTITION BY company, location, industry, total_laid_off, 
  percentage_laid_off, `date`, stage, country, funds_raised_millions
) AS row_num
FROM layoffs_staging
WHERE row_num > 1;

-- Create second staging table with row numbers
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Insert data with row numbers
INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
  PARTITION BY company, location, industry, total_laid_off, 
  percentage_laid_off, `date`, stage, country, funds_raised_millions
) AS row_num
FROM layoffs_staging;

-- Remove duplicate rows (keep row_num = 1 only)
DELETE FROM layoffs_staging2
WHERE row_num > 1;

SELECT *
FROM layoffs_staging2;

-- STEP 4: STANDARDIZE DATA
-- 4.1: Trim whitespace from company names
SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

-- 4.2: Fix industry inconsistencies (Crypto variants)
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY 1;

SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- 4.3: Fix country formatting (trailing periods)
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

SELECT *
FROM layoffs_staging2
WHERE country LIKE 'United States%';

SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- 4.4: Convert date format (TEXT to DATE)
SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

SELECT `date`
FROM layoffs_staging2;

-- STEP 5: HANDLE NULL/MISSING VALUES
-- 5.1: Identify rows with both layoff metrics missing (unusable data)
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- 5.2: Clean up empty strings in industry column
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- 5.3: Check for null industries
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
OR industry = '';

-- 5.4: Fill null industries using company name match
-- Example: if Airbnb has both null and non-null industry, fill the null
SELECT t1.company, t1.location, t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

-- STEP 6: REMOVE UNNECESSARY DATA
-- 6.1: Remove rows with no usable layoff data
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- 6.2: Remove row_num column (no longer needed)
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- STEP 7: FINAL VERIFICATION
SELECT *
FROM layoffs_staging2;

-- Check final row count
SELECT COUNT(*) AS total_records
FROM layoffs_staging2;

-- Check for remaining nulls by column
SELECT 
  COUNT(CASE WHEN company IS NULL THEN 1 END) AS null_company,
  COUNT(CASE WHEN location IS NULL THEN 1 END) AS null_location,
  COUNT(CASE WHEN industry IS NULL THEN 1 END) AS null_industry,
  COUNT(CASE WHEN total_laid_off IS NULL THEN 1 END) AS null_total_laid_off,
  COUNT(CASE WHEN percentage_laid_off IS NULL THEN 1 END) AS null_percentage_laid_off,
  COUNT(CASE WHEN `date` IS NULL THEN 1 END) AS null_date,
  COUNT(CASE WHEN stage IS NULL THEN 1 END) AS null_stage,
  COUNT(CASE WHEN country IS NULL THEN 1 END) AS null_country,
  COUNT(CASE WHEN funds_raised_millions IS NULL THEN 1 END) AS null_funds
FROM layoffs_staging2;
