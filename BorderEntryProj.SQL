https://www.bts.gov/explore-topics-and-geography/geography/border-crossingentry-data#1


--Total number of entries all time
SELECT
	SUM(value)
FROM
	border_entry_data;

--Find out the time frame data has been recorded
SELECT
	MAX(date),
	MIN(date)
FROM
	border_entry_data;


--Find out the states
SELECT
	state_name
FROM
	border_entry_data
GROUP BY
	state_name;

--Find out the amount of ports per state 
SELECT
	state_name,
	COUNT(DISTINCT port_code) AS PORTS
FROM
	border_entry_data
GROUP BY
	state_name
ORDER BY
	state_name;

--Find out the total amount of ports 
SELECT
	COUNT(DISTINCT port_code)
FROM
	border_entry_data;

--Find out the avg entries from mexico to us and canada to us by day, week, month, year 
SELECT
	border,
	-- Data only has the first of the months so must find number of days as diff from end to start date
	(SUM(value)/(MAX(date)-MIN(date))) AS avg_day,
	-- SImilarly, we divide number of days by 7 to return number of weeks
	(SUM(value)/((MAX(date)-MIN(date))/7)) AS avg_week,
	(SUM(value)/COUNT(DISTINCT DATE_TRUNC('month',date))) AS avg_month,
	(SUM(value)/COUNT(DISTINCT DATE_TRUNC('year',date))) AS avg_year
FROM
	border_entry_data
GROUP BY border;

--Find out the on the month and what port, the highest number of entries occurred 
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

--Find out the 'most popular' port of entry by avg 
SELECT
	port_name,
	state_name,
	longitude,
	latitude,
	AVG(value) AS total_entries
FROM
	border_entry_data
GROUP BY port_name,state_name,longitude,latitude
ORDER BY total_entries DESC
LIMIT 5;

--Find out the 'most popular' port of entry by total entries 
SELECT
	port_name,
	state_name,
	longitude,
	latitude,
	SUM(value) AS total_entries
FROM
	border_entry_data
GROUP BY port_name,state_name,longitude,latitude
ORDER BY total_entries DESC
LIMIT 5;

--The least popular ports of entry by avg
SELECT
	port_name,
	state_name,
	longitude,
	latitude,
	AVG(value) AS avg_entries
FROM
	border_entry_data
GROUP BY port_name,state_name,longitude,latitude
ORDER BY avg_entries 
LIMIT 5;

--The least popular ports of entry by total
SELECT
	port_name,
	state_name,
	SUM(value) AS total_entries
FROM
	border_entry_data
GROUP BY port_name,state_name
ORDER BY total_entries 
LIMIT 5;

--The # of entry points in the north vs south
SELECT
	border,
	COUNT(DISTINCT port_code)
FROM
	border_entry_data
GROUP BY border;

--The # of entries by method in total and percentage
SELECT
    measure,
    SUM(value) AS grouped_sum,
    SUM(value)*100/SUM(SUM(value)) OVER () AS percent_of_total
FROM
    border_entry_data
GROUP BY
    measure
ORDER BY percent_of_total DESC;

--The # of entries by method by border in total and percentage
SELECT
    border,
	measure,
    SUM(value) AS total,
	SUM(value)*100/total_sum::NUMERIC AS percent_of_total,
	--RANKS the popularity by type from border 0 is all types summed
	RANK() OVER(PARTITION BY border ORDER BY SUM(value)*100/total_sum::NUMERIC DESC)-1 AS most_pop_type_per_border
FROM
    border_entry_data
--I cross join here to get an instance of only the total sum included into the original table
--this is needed to calculate % total
CROSS JOIN (
        SELECT SUM(value) AS total_sum FROM border_entry_data
    ) t
GROUP BY
   	ROLLUP(border,measure),total_sum
ORDER BY border;

--Gives us the different means of entry and their popularity by state
SELECT
	state_name,
	measure,
	SUM(value)
FROM
	border_entry_data
GROUP BY
	state_name,
	measure
ORDER BY 
	state_name,entries DESC;

--distribution of total entries over time I am unsure if this is better per year or per month
--SO I will do both and decide later :)
SELECT
	DATE_TRUNC('year', date) AS per_year,
	SUM(value)
FROM
	border_entry_data
GROUP BY
	per_year
ORDER BY 
	per_year;
SELECT
	date AS per_month,
	SUM(value)
FROM
	border_entry_data
GROUP BY
	per_month
ORDER BY 
	per_month;

--find out which states have the highest entry by each type on avg, 
--in other words, where are the most popular version of each measure entering from
WITH
--first table that finds avg entry by state and type
	T1 AS (
		SELECT
			STATE_NAME,
			MEASURE,
			AVG(VALUE) AS NUM_ENTRIES
		FROM
			BORDER_ENTRY_DATA
		GROUP BY
			MEASURE,
			STATE_NAME
	),
--second table to find the max avg value by type
	T2 AS (
		SELECT
			MEASURE,
			MAX(NUM_ENTRIES) AS HIGHEST_AVG
		FROM
			T1
		GROUP BY
			MEASURE
	)
SELECT
	T2.MEASURE,
	ROUND(T2.HIGHEST_AVG,2),
	T1.STATE_NAME
FROM
	T2
	LEFT JOIN T1 ON T1.NUM_ENTRIES = T2.HIGHEST_AVG
--left join t1 to t2 to keep only rows that include max avg entry 

--To make a query that can be edited with minimal effort for the future (because i want to make one for each measure)
-- I can create the following framework to use as a list in the where clause later on
--This function has the row numbers and measures to let us know we will need 1-12 in the twelve diff. q's in our where
WITH l1 AS (
	SELECT measure,
			row_number() OVER (ORDER BY measure)
		FROM
			(SELECT DISTINCT measure FROM border_entry_data))
SELECT * FROM l1
	
--Use the same q' as before but now join 'l1' values in 'l2' so that we can filter by row number i.e. filter by measure even if it is unknown
--To find what measure is being referenced, refer to table in previous query
WITH
	L1 AS (
		SELECT
			MEASURE AS OLD_MEASURE,
			ROW_NUMBER() OVER (
				ORDER BY
					MEASURE
			) AS RN
		FROM
			(
				SELECT DISTINCT
					MEASURE
				FROM
					BORDER_ENTRY_DATA
			)
	),
	L2 AS (
		SELECT
			*
		FROM
			BORDER_ENTRY_DATA AS BED
			LEFT JOIN L1 ON BED.MEASURE = L1.OLD_MEASURE
	)
	--create the data table to show progression and potential trends per month (use this same query but replace 1 with next num for next measure)
SELECT
	DATE_TRUNC('year', DATE) AS YEAR_DATE,
	DATE,
	MEASURE,
	SUM(VALUE) AS PER_MONTH
FROM
	L2
WHERE
	RN = 1
GROUP BY
	YEAR_DATE,
	DATE,
	MEASURE
ORDER BY
	YEAR_DATE,
	DATE

-- Gives us the history of top 5 ports for each month
SELECT
	*
FROM
	(
		SELECT
			DATE,
			--Concat state name onto port
			PORT_NAME || ', ' || STATE_NAME AS NAMED,
			SUM(VALUE) AS ENTRIES,
			--Assign ranked based on total entries per month
			RANK() OVER (
				PARTITION BY
					DATE
				ORDER BY
					SUM(VALUE) DESC
			) AS RANKED
		FROM
			BORDER_ENTRY_DATA
		GROUP BY
			DATE,
			NAMED
		ORDER BY
			DATE
	)
--limit to only the top 5 ports per month
WHERE
	RANKED <= 5;

