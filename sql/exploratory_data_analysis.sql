-- EXPLORATORY DATA ANALYSIS - LAYOFFS

-- Data Overview
-- View all cleaned data
SELECT *
FROM layoffs_staging2;

-- Check max values and basic statistics
SELECT 
  MAX(total_laid_off) AS max_total_laid_off,
  MAX(percentage_laid_off) AS max_percentage_laid_off
FROM layoffs_staging2;

-- Check date range in dataset
SELECT 
  MIN(`date`) AS earliest_date,
  MAX(`date`) AS latest_date
FROM layoffs_staging2;

-- Company Analysis
-- Total layoffs by company
SELECT 
  company,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

-- Companies with complete shutdown (100% layoff)
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- Company layoffs by year
SELECT 
  company,
  YEAR(`date`) AS year,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC;

-- Top 5 companies by layoffs in each year
WITH company_year AS (
  SELECT 
    company,
    YEAR(`date`) AS years,
    SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  GROUP BY company, YEAR(`date`)
),
company_year_rank AS (
  SELECT *,
    DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS ranking
  FROM company_year
  WHERE years IS NOT NULL
)
SELECT *
FROM company_year_rank
WHERE ranking <= 5;

-- Industry Analysis
-- Total layoffs by industry
SELECT 
  industry,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;

-- Geographic Analysis
-- Total layoffs by country
SELECT 
  country,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;

-- Funding Stage Analysis
-- Total layoffs by company stage
SELECT 
  stage,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;

-- Time Series Analysis
-- Monthly total layoffs
SELECT 
  SUBSTRING(`date`, 1, 7) AS month,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `month`
ORDER BY 1 ASC;

-- Yearly total layoffs
SELECT 
  YEAR(`date`) AS year,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 2 DESC;

-- Rolling Total - Cumulative layoffs over time
WITH rolling_total AS (
  SELECT 
    SUBSTRING(`date`, 1, 7) AS month,
    SUM(total_laid_off) AS total_off
  FROM layoffs_staging2
  WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
  GROUP BY `month`
  ORDER BY 1 ASC
)
SELECT 
  `month`,
  total_off,
  SUM(total_off) OVER (ORDER BY `month`) AS rolling_total_value
FROM rolling_total;

-- ============================================================================
-- Business Question Based Queries
-- ============================================================================
-- QUERY 1: Recurring Companies
-- Business Question: Which companies are most unstable (multiple layoff rounds)?
SELECT 
  company,
  COUNT(*) AS layoff_count,
  SUM(total_laid_off) AS total_employees_laid_off,
  MIN(`date`) AS first_layoff,
  MAX(`date`) AS latest_layoff
FROM layoffs_staging2
WHERE company IS NOT NULL AND total_laid_off IS NOT NULL
GROUP BY company
HAVING COUNT(*) > 1
ORDER BY layoff_count DESC
LIMIT 15;

-- QUERY 2: Layoff Severity Breakdown
-- Business Question: How severe are the layoffs - shutdowns vs partial cuts?
SELECT 
  CASE 
    WHEN percentage_laid_off = 1 THEN 'Complete Shutdown (100%)'
    WHEN percentage_laid_off >= 0.5 THEN 'Major Layoff (50-99%)'
    WHEN percentage_laid_off > 0 THEN 'Partial Layoff (<50%)'
    ELSE 'Unknown'
  END AS severity,
  COUNT(*) AS num_events,
  SUM(total_laid_off) AS total_employees,
  AVG(total_laid_off) AS avg_per_event
FROM layoffs_staging2
WHERE percentage_laid_off IS NOT NULL
GROUP BY severity
ORDER BY num_events DESC;

-- QUERY 3: Industry Trends Over Years
-- Business Question: Which industries were hit hardest each year?
SELECT 
  YEAR(`date`) AS year,
  industry,
  SUM(total_laid_off) AS total_laid_off,
  COUNT(*) AS num_events
FROM layoffs_staging2
WHERE industry IS NOT NULL AND `date` IS NOT NULL
GROUP BY YEAR(`date`), industry
ORDER BY year DESC, total_laid_off DESC;

-- QUERY 4: Top Cities with Most Layoffs
-- Business Question: Which geographic cities/regions are affected most?
SELECT 
  location,
  country,
  COUNT(*) AS num_events,
  SUM(total_laid_off) AS total_laid_off,
  COUNT(DISTINCT company) AS num_companies
FROM layoffs_staging2
WHERE location IS NOT NULL
GROUP BY location, country
ORDER BY total_laid_off DESC
LIMIT 15;

-- QUERY 5: Funding Stage & Layoff Size Correlation
-- Business Question: Do well-funded companies lay off more or less than startups?
SELECT 
  stage,
  COUNT(*) AS num_events,
  AVG(funds_raised_millions) AS avg_funding_raised,
  SUM(funds_raised_millions) AS total_funding_in_stage,
  AVG(total_laid_off) AS avg_layoff_size
FROM layoffs_staging2
WHERE stage IS NOT NULL AND total_laid_off IS NOT NULL
GROUP BY stage
ORDER BY avg_layoff_size DESC;