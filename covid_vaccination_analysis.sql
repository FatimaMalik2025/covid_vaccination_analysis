-- Filtering Out Continents Repeated as Location 
SELECT *
FROM covid_vaccinations
WHERE continent IS NOT NULL; 

-- Finding Most Troubled Continents With Highest Fatality and Spread 
SELECT continent, 
	   (MAX(total_cases)/NULLIF(MAX(population),0)) * 100 AS infection_rate, 
	   (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0  AS death_rate, 
	   ((MAX(total_cases)/NULLIF(MAX(population),0)) * 100  + 
       (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0 ) AS trouble_index
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY trouble_index DESC;

-- Finding Most Troubled Countries With Highest Fatality and Spread 
SELECT location, 
	   MAX(population) AS population, 
       MAX(total_cases) AS total_cases,
	   (MAX(total_cases)/NULLIF(MAX(population),0)) * 100 AS infection_rate, 
	   (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0  AS death_rate, 
	   ((MAX(total_cases)/NULLIF(MAX(population),0)) * 100  *
       (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0 ) AS trouble_index
FROM covid_deaths
WHERE continent IS NOT NULL 
GROUP BY location
ORDER BY trouble_index DESC
LIMIT 10;

-- Global Cases and Deaths 
SELECT SUM(total_cases) AS total_cases, 
	   SUM(total_deaths) AS total_deaths, 
       (SUM(total_deaths) /SUM(total_cases)) * 100.0 AS death_rate
FROM covid_deaths;

-- Top 10 Highest Global Deaths Per Day 
SELECT date, SUM(total_cases) AS total_cases,
			 SUM(total_deaths) AS total_deaths, 
             (SUM(total_deaths) /SUM(total_cases)) * 100.0 AS death_rate
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY death_rate DESC 
LIMIT 10;

-- Top 10 Highest Global Cases Per Day 
SELECT date, SUM(total_cases) AS total_cases, 
			 SUM(total_deaths) AS total_deaths, 
             (SUM(total_deaths) /SUM(total_cases)) * 100.0 AS death_rate
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY total_cases DESC 
LIMIT 10;

-- Progression of Vaccination Rollout
SELECT deaths.continent, 
	   deaths.location, 
	   deaths.date,
       deaths.population, 
       vaccinations.new_vaccinations, 
	   SUM(vaccinations.new_vaccinations) OVER (PARTITION BY deaths.location ORDER BY deaths.date) AS rolling_people_vaccinated
FROM covid_deaths deaths 
JOIN covid_vaccinations  vaccinations ON deaths.location = vaccinations.location AND deaths.date = vaccinations.date
WHERE deaths.continent IS NOT NULL;

-- Looking at Total Population Vs Total Vaccinations
WITH pop_vs_vac AS(
	SELECT d.location, MAX(d.date) AS date, 
					   MAX(d.population) AS population, 
                       MAX(v.total_vaccinations) AS total_vaccination, 
					   MAX(v.people_vaccinated) AS people_vaccinated, 
                       MAX(v.people_fully_vaccinated) AS people_fully_vaccinated
    FROM covid_deaths d 
	JOIN covid_vaccinations v ON d.location = v.location AND d.date = v.date
    WHERE d.continent IS NOT NULL 
    GROUP BY d.location
)
SELECT location, date, ((people_vaccinated - people_fully_vaccinated)/population) * 100.0 AS one_dose_rate, 
				(people_fully_vaccinated/population) * 100.0 AS fully_vaccinated_rate, 
                (people_vaccinated/population) * 100.0 AS total_coverage
FROM pop_vs_vac
ORDER BY total_coverage DESC
LIMIT 10;
-- Countries Where Majority Did Not Receive Full Dose 
WITH pop_vs_vac AS(
	SELECT d.location, MAX(d.date) AS date, 
					   MAX(d.population) AS population, 
                       MAX(v.total_vaccinations) AS total_vaccination, 
					   MAX(v.people_vaccinated) AS people_vaccinated, 
                       MAX(v.people_fully_vaccinated) AS people_fully_vaccinated
    FROM covid_deaths d 
	JOIN covid_vaccinations v ON d.location = v.location AND d.date = v.date
    WHERE d.continent IS NOT NULL 
    GROUP BY d.location
)
SELECT location, date, ((people_vaccinated - people_fully_vaccinated)/population) * 100.0 AS one_dose_rate, 
				(people_fully_vaccinated/population) * 100.0 AS fully_vaccinated_rate, 
                (people_vaccinated/population) * 100.0 AS total_coverage
FROM pop_vs_vac
WHERE ((people_vaccinated - people_fully_vaccinated)/population) * 100.0 > (people_fully_vaccinated/population) * 100.0
ORDER BY total_coverage DESC
LIMIT 10;
-- Death Rate Improvement Since Introduction of Vaccine 
WITH first_date_vaccine AS(
SELECT d.location, MIN(d.date) AS first_vaccine_date
FROM covid_deaths d
JOIN covid_vaccinations v ON d.location =  v.location AND d.date = v.date
WHERE d.continent IS NOT NULL AND v.people_vaccinated > 0 
GROUP BY d.location 
), 
death_rate_first AS (
SELECT d.location, (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0  AS death_rate_first, fd.first_vaccine_date
FROM covid_deaths d 
JOIN first_date_vaccine fd ON d.location = fd.location AND d.date = fd.first_vaccine_date
GROUP BY d.location), 
death_rate_latest AS (
SELECT d.location, (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0  AS death_rate_last
FROM covid_deaths d 
JOIN covid_vaccinations v ON d.location = v.location AND d.date = v.date
GROUP BY d.location)
SELECT  df.location, 
		df.first_vaccine_date, 
		df.death_rate_first, 
        dl.death_rate_last, 
		(df.death_rate_first - dl.death_rate_last) AS death_rate_improvement
FROM death_rate_first df
JOIN death_rate_latest dl ON df.location = dl.location
WHERE df.location = "Maldives"
ORDER BY death_rate_improvement DESC;

-- Most Troubled Countries With No Vaccines
WITH trouble_index AS (
    SELECT location,
           (MAX(total_cases)/NULLIF(MAX(population),0)) * 100 AS infection_rate,
           (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100 AS death_rate,
           ((MAX(total_cases)/NULLIF(MAX(population),0)) * 100 *
            (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100) AS trouble_score
    FROM covid_deaths
    WHERE continent IS NOT NULL
    GROUP BY location
),
max_vaccinations AS (
    SELECT location, MAX(total_vaccinations) AS max_total_vaccinations
    FROM covid_vaccinations
    GROUP BY location
)
SELECT t.location,
       t.infection_rate,
       t.death_rate,
       t.trouble_score
FROM trouble_index t
JOIN max_vaccinations v ON t.location = v.location
WHERE v.max_total_vaccinations IS NULL
ORDER BY t.trouble_score DESC;

-- External Factors Effecting Vaccine Campaign From Improving Death Rates 
WITH first_date_vaccine AS(
SELECT d.location, MIN(d.date) AS first_vaccine_date
FROM covid_deaths d
JOIN covid_vaccinations v ON d.location =  v.location AND d.date = v.date
WHERE d.continent IS NOT NULL AND v.people_vaccinated > 0
GROUP BY d.location 
), 
death_rate_first AS (
SELECT d.location, (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0  AS death_rate_first, fd.first_vaccine_date
FROM covid_deaths d 
JOIN first_date_vaccine fd ON d.location = fd.location AND d.date = fd.first_vaccine_date
GROUP BY d.location), 
death_rate_latest AS (
SELECT d.location, (MAX(total_deaths)/NULLIF(MAX(total_cases),0)) * 100.0  AS death_rate_last
FROM covid_deaths d 
JOIN covid_vaccinations v ON d.location = v.location AND d.date = v.date
GROUP BY d.location),
negative_improvement AS(
SELECT  df.location, 
		df.first_vaccine_date, 
        df.death_rate_first, 
        dl.death_rate_last, 
		(df.death_rate_first - dl.death_rate_last) AS death_rate_change
FROM death_rate_first df
JOIN death_rate_latest dl ON df.location = dl.location 
WHERE df.death_rate_first - dl.death_rate_last < 0 
ORDER BY death_rate_change DESC
)
SELECT n.location, n.death_rate_change, 
      MAX(v.gdp_per_capita) AS gdp_per_capita, 
	  MAX(v.human_development_index) AS human_development_index,
	  MAX(v.extreme_poverty) AS extreme_poverty, 
      MAX(v.life_expectancy) AS life_expectancy,
      MAX(v.hospital_beds_per_thousand) AS hospital_beds_per_thousand
      
FROM negative_improvement n
JOIN covid_vaccinations v ON n.location = v.location 
GROUP BY n.location, n.death_rate_change
ORDER BY death_rate_change ASC, human_development_index DESC, gdp_per_capita DESC, hospital_beds_per_thousand
LIMIT 10;




