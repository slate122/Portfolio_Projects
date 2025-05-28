/* https://www.bts.gov/explore-topics-and-geography/geography/border-crossingentry-data#1
Written in PostgreSQL 17.5 
Assumes table: border_entry_data with columns (date, port_code, port_name, state_name, border, measure, value, latitude, longitude)
*/

-- Total number of all recorded entries across all time and all ports
SELECT
	SUM(value)
FROM
	border_entry_data;

-- Timeframe of available data (start and end dates)
SELECT
	MAX(date), -- Most recent entry
	MIN(date)  -- Earliest recorded entry
FROM
	border_entry_data;

-- List of all U.S. states appearing in dataset
SELECT
	state_name
FROM
	border_entry_data
GROUP BY
	state_name;

-- Count of distinct ports per state (how many entry points each state has)
SELECT
	state_name,
	COUNT(DISTINCT port_code) AS PORTS
FROM
	border_entry_data
GROUP BY
	state_name
ORDER BY
	state_name;

-- Total number of distinct ports (nationwide)
SELECT
	COUNT(DISTINCT port_code)
FROM
	border_entry_data;

-- Average entries by day/week/month/year for each border
SELECT
	border,
	-- Average per day: total divided by range in days
	(SUM(value)/(MAX(date)-MIN(date))) AS avg_day,
	-- Approximate average per week
	(SUM(value)/((MAX(date)-MIN(date))/7)) AS avg_week,
	-- Monthly average using number of distinct months
	(SUM(value)/COUNT(DISTINCT DATE_TRUNC('month', date))) AS avg_month,
	-- Yearly average using number of distinct years
	(SUM(value)/COUNT(DISTINCT DATE_TRUNC('year', date))) AS avg_year
FROM
	border_entry_data
GROUP BY border;

-- Top 10 highest entry records (month+port+measure with highest volumes)
SELECT
	date,
	port_name,
	state_name,
	measure,
	value
FROM
	border_entry_data
ORDER BY
	value DESC
LIMIT 10;

-- Top 5 most popular ports by AVERAGE number of entries
SELECT
	port_name,
	state_name,
	longitude,
	latitude,
	AVG(value) AS total_entries
FROM
	border_entry_data
GROUP BY port_name, state_name, longitude, latitude
ORDER BY total_entries DESC
LIMIT 5;

-- Top 5 most popular ports by TOTAL number of entries
SELECT
	port_name,
	state_name,
	longitude,
	latitude,
	SUM(value) AS total_entries
FROM
	border_entry_data
GROUP BY port_name, state_name, longitude, latitude
ORDER BY total_entries DESC
LIMIT 5;

-- Bottom 5 least popular ports by AVERAGE entries
SELECT
	port_name,
	state_name,
	longitude,
	latitude,
	AVG(value) AS avg_entries
FROM
	border_entry_data
GROUP BY port_name, state_name, longitude, latitude
ORDER BY avg_entries
LIMIT 5;

-- Bottom 5 least popular ports by TOTAL entries
SELECT
	port_name,
	state_name,
	SUM(value) AS total_entries
FROM
	border_entry_data
GROUP BY port_name, state_name
ORDER BY total_entries
LIMIT 5;

-- Number of distinct ports per border (e.g., northern vs southern)
SELECT
	border,
	COUNT(DISTINCT port_code)
FROM
	border_entry_data
GROUP BY border;

-- Total entries by method (e.g., pedestrian, vehicle, rail), and percentage of total
SELECT
    measure,
    SUM(value) AS grouped_sum,
    SUM(value) * 100 / SUM(SUM(value)) OVER () AS percent_of_total
FROM
    border_entry_data
GROUP BY
    measure
ORDER BY percent_of_total DESC;

-- Total and percentage of entries per method, broken down by border
SELECT
    border,
	measure,
    SUM(value) AS total,
	SUM(value) * 100 / total_sum::NUMERIC AS percent_of_total,
	RANK() OVER(PARTITION BY border ORDER BY SUM(value) * 100 / total_sum::NUMERIC DESC) - 1 AS most_pop_type_per_border
FROM
    border_entry_data
-- Use CROSS JOIN to include total sum in each row for percentage calculation
CROSS JOIN (
        SELECT SUM(value) AS total_sum FROM border_entry_data
    ) t
GROUP BY
   	ROLLUP(border, measure), total_sum
ORDER BY border;

-- Method of entry usage per state (e.g., California: pedestrian, vehicle...)
SELECT
	state_name,
	measure,
	SUM(value) AS entries
FROM
	border_entry_data
GROUP BY
	state_name,
	measure
ORDER BY 
	state_name, entries DESC;

-- Distribution of total entries per year
SELECT
	DATE_TRUNC('year', date) AS per_year,
	SUM(value)
FROM
	border_entry_data
GROUP BY
	per_year
ORDER BY 
	per_year;

-- Distribution of total entries per month
SELECT
	date AS per_month,
	SUM(value)
FROM
	border_entry_data
GROUP BY
	per_month
ORDER BY 
	per_month;

-- State with highest average number of entries per measure type (most popular state per method)
WITH
-- Table T1: avg value per state & method
	T1 AS (
		SELECT
			state_name,
			measure,
			AVG(value) AS num_entries
		FROM
			border_entry_data
		GROUP BY
			measure,
			state_name
	),
-- Table T2: max avg per method
	T2 AS (
		SELECT
			measure,
			MAX(num_entries) AS highest_avg
		FROM
			T1
		GROUP BY
			measure
	)
-- Join to get the state corresponding to each highest method avg
SELECT
	T2.measure,
	ROUND(T2.highest_avg, 2),
	T1.state_name
FROM
	T2
	LEFT JOIN T1 ON T1.num_entries = T2.highest_avg;

-- Create reusable lookup for assigning row numbers to each unique measure
WITH l1 AS (
	SELECT measure,
			ROW_NUMBER() OVER (ORDER BY measure)
		FROM
			(SELECT DISTINCT measure FROM border_entry_data)
)
SELECT * FROM l1;

-- Generalized framework to analyze a single method (via row number) over time
WITH
	L1 AS (
		SELECT
			measure AS old_measure,
			ROW_NUMBER() OVER (ORDER BY measure) AS rn
		FROM
			(SELECT DISTINCT measure FROM border_entry_data)
	),
	L2 AS (
		SELECT
			*
		FROM
			border_entry_data AS bed
			LEFT JOIN L1 ON bed.measure = L1.old_measure
	)
-- Output total entries per month for the selected method (rn = 1 = first method alphabetically)
SELECT
	DATE_TRUNC('year', date) AS year_date,
	date,
	measure,
	SUM(value) AS per_month
FROM
	L2
WHERE
	rn = 1
GROUP BY
	year_date,
	date,
	measure
ORDER BY
	year_date,
	date;

-- Historical top 5 ports by entries each month
SELECT
	*
FROM (
		SELECT
			date,
			port_name || ', ' || state_name AS named, -- Combined label
			SUM(value) AS entries,
			RANK() OVER (
				PARTITION BY date
				ORDER BY SUM(value) DESC
			) AS ranked
		FROM
			border_entry_data
		GROUP BY
			date, named
		ORDER BY
			date
	) ranked_data
WHERE
	ranked <= 5;
