/* ============================================================
   Project: Restaurant Demand Pressure Analysis
   Database: restaurant_analytics
   Purpose : Centralize analytical logic for Tableau dashboards
   ============================================================ */

USE restaurant_analytics;

/* ------------------------------------------------------------
   View: vw_daily_demand_context
   Description:
   Combines calendar features with external demand drivers
   and the computed demand pressure index.
   ------------------------------------------------------------ */

CREATE OR REPLACE VIEW vw_daily_demand_context AS
SELECT
    c.date,
    c.year,
    c.month,
    c.month_name,
    c.weekday_name,
    c.is_weekend,
    c.is_holiday,

    w.avg_temperature,
    w.precipitation,

    t.hotel_occupancy_rate,

    d.demand_pressure_index

FROM calendar_dim c
LEFT JOIN weather_daily w
    ON c.date = w.date
LEFT JOIN tourism_daily t
    ON c.date = t.date
LEFT JOIN demand_pressure_daily d
    ON c.date = d.date;

/* ------------------------------------------------------------
   View: vw_monthly_pressure_summary
   Description:
   Monthly aggregation of demand pressure and tourism levels
   used for trend and seasonality analysis.
   ------------------------------------------------------------ */

CREATE OR REPLACE VIEW vw_monthly_pressure_summary AS
SELECT
    year,
    month,
    month_name,

    AVG(demand_pressure_index) AS avg_demand_pressure,
    MAX(demand_pressure_index) AS peak_demand_pressure,
    AVG(hotel_occupancy_rate) AS avg_hotel_occupancy

FROM vw_daily_demand_context
GROUP BY
    year,
    month,
    month_name
ORDER BY
    year,
    month;

/* ------------------------------------------------------------
   View: vw_holiday_vs_nonholiday
   Description:
   Compares demand pressure metrics between holidays
   and non-holiday days.
   ------------------------------------------------------------ */

CREATE OR REPLACE VIEW vw_holiday_vs_nonholiday AS
SELECT
    is_holiday,

    COUNT(*) AS days_count,
    AVG(demand_pressure_index) AS avg_demand_pressure,
    MAX(demand_pressure_index) AS peak_demand_pressure,
    AVG(hotel_occupancy_rate) AS avg_hotel_occupancy

FROM vw_daily_demand_context
GROUP BY
    is_holiday;

/* ------------------------------------------------------------
   View: vw_weather_impact
   Description:
   Groups days by rounded temperature to assess how
   demand pressure changes with weather conditions.
   ------------------------------------------------------------ */

CREATE OR REPLACE VIEW vw_weather_impact AS
SELECT
    ROUND(avg_temperature, 0) AS temperature_bucket,

    COUNT(*) AS days_count,
    AVG(demand_pressure_index) AS avg_demand_pressure,
    MAX(demand_pressure_index) AS peak_demand_pressure

FROM vw_daily_demand_context
WHERE avg_temperature IS NOT NULL
GROUP BY
    ROUND(avg_temperature, 0)
ORDER BY
    temperature_bucket;

/* ------------------------------------------------------------
   View: vw_restaurant_exposure
   Description:
   Combines restaurant popularity with city demand pressure
   to calculate an exposure index.
   ------------------------------------------------------------ */

CREATE OR REPLACE VIEW vw_restaurant_exposure AS
SELECT
    r.restaurant_id,
    r.restaurant_name,
    r.city,
    r.primary_cuisine,
    r.price_level,
    r.rating,
    r.num_reviews,
    r.ranking,
    r.popularity_score,

    AVG(d.demand_pressure_index) AS avg_city_pressure,
    MAX(d.demand_pressure_index) AS peak_city_pressure,

    -- Exposure Index
    AVG(d.demand_pressure_index) * r.popularity_score AS exposure_index

FROM restaurants_lisbon r
CROSS JOIN demand_pressure_daily d
GROUP BY
    r.restaurant_id,
    r.restaurant_name,
    r.city,
    r.primary_cuisine,
    r.price_level,
    r.rating,
    r.num_reviews,
    r.ranking,
    r.popularity_score;

/* ------------------------------------------------------------
   Validation & sanity checks
   ------------------------------------------------------------ */

-- Check view creation
SHOW FULL TABLES WHERE Table_type = 'VIEW';

-- Sample data
SELECT * FROM vw_daily_demand_context LIMIT 10;
SELECT * FROM vw_restaurant_exposure ORDER BY exposure_index DESC LIMIT 10;
