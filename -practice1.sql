SHOW TABLES;

SHOW ALL TABLES; -- 'temporary'-false means not a temp table

DESCRIBE claim;

SUMMARIZE claim; -- some descriptive stats

SELECT *
FROM claim
INNER JOIN car ON claim.car_id = car.id; -- JOIN = INNER JOIN

SELECT *
FROM claim
LEFT JOIN car ON claim.car_id = car.id; -- L claim, R car

SELECT *
FROM claim
RIGHT JOIN car ON claim.car_id = car.id;

SELECT *        -- SELECT COUNT(*) shows total no. of entries
FROM claim
FULL JOIN car ON claim.car_id = car.id -- FUL JOIN = FULL OUTER JOIN
WHERE claim.car_id IS NULL;


-- Solution for Ex.3 Master Report  
SELECT   
    cl.id, cl.claim_date, cl.claim_amt,  
    c.car_type,  
    cli.first_name, cli.last_name,  
    a.city, a.state  
FROM claim cl  
INNER JOIN car c ON cl.car_id = c.id  
INNER JOIN client cli ON cl.client_id = cli.id  
INNER JOIN address a ON cli.address_id = a.id;  

-- can consider LEFT JOIN to keep data for ML


SELECT 
    id, claim_amt,
    SUM(claim_amt) OVER (ORDER BY id) AS running_total -- after OVER is the window
FROM claim;

SELECT
  id, car_id, claim_amt,
  SUM(claim_amt) OVER (PARTITION BY car_id ORDER BY id) AS running_total
FROM claim;
-- e.g. car_id 58 is one partition, total=0+5+0


-- Ex. 4 cumulative insurance payouts over time 
SELECT   
    claim_date, claim_amt,  
    SUM(claim_amt) OVER (ORDER BY claim_date) AS running_total  
FROM claim;  

SELECT SUM(claim_amt) FROM claim; -- to see total claim amt only


SELECT 
    id, car_id, claim_amt,
    RANK() OVER (PARTITION BY car_id ORDER BY claim_amt DESC) AS amt_rank 
FROM claim;

SELECT 
    id, car_id, claim_amt,
    ROW_NUMBER() OVER (PARTITION BY car_id ORDER BY claim_amt DESC) AS amt_rank
FROM claim;


-- Ranking Window - who has the highest claims per car category?
SELECT
  cl.id, c.car_type, cl.claim_amt,
  RANK() OVER (
    PARTITION BY car_type
    ORDER BY claim_amt DESC
  ) AS rank
FROM claim cl
JOIN car c ON cl.car_id = c.id
QUALIFY rank = 1       -- after WINDOW fn, use QUALIFY for filtering
ORDER BY cl.claim_amt DESC; 

--  find cars that have been involved in a claim
SELECT id, resale_value, car_type
FROM car
WHERE id IN (
    SELECT DISTINCT car_id
    FROM claim
);


--- find cars that have been involved in a claim, and claim amt >10% of car's resale value
SELECT id, resale_value, car_type
FROM car c
WHERE id IN (
  SELECT DISTINCT car_id
  FROM claim
  WHERE claim_amt > 0.1 * c.resale_value
);

-- similar to INNER JOIN \ find cars involved in a claim
SELECT id, resale_value, car_type
FROM car c1
WHERE EXISTS (
  SELECT DISTINCT car_id
  FROM claim c2
  WHERE c2.car_id = c1.id
);


-- find cars involved in a claim, and resale value < average resale value for the car car_type
-- need to compute avg using subquery -> pass to out query
SELECT id, resale_value, c1.car_type
FROM car c1
INNER JOIN (
  SELECT car_type, AVG(resale_value) AS average_resale_value
  FROM car
  GROUP BY car_type
) c2 ON c1.car_type = c2.car_type
WHERE resale_value < average_resale_value;


-- subqueries can be difficult to read, can be replaced by CTE
-- use CTE instead of subquery for readability

WITH avg_resale_value_by_car_type AS (
  SELECT car_type, AVG(resale_value) AS average_resale_value
  FROM car
  GROUP BY car_type
)
SELECT id, resale_value, c1.car_type
FROM car c1
INNER JOIN avg_resale_value_by_car_type c2 ON c1.car_type = c2.car_type
WHERE resale_value < average_resale_value;


-- CTE Approach (Clean & Readable) find cars whose resale value < average for their specific type
WITH AvgValues AS (  
    SELECT car_type, AVG(resale_value) as avg_resale  
    FROM car  
    GROUP BY car_type  
)  
SELECT c.id, c.car_type, c.resale_value, a.avg_resale  
FROM car c  
JOIN AvgValues a ON c.car_type = a.car_type  
WHERE c.resale_value < a.avg_resale;


-- Ex.5 Find clients who have made claims that are more than 50% of their annual income
-- Use a CTE to calculate the total claims per client first.
WITH TotalClaims AS (  
    SELECT client_id, SUM(claim_amt) as sum_claim 
    FROM claim  
    GROUP BY client_id
)  
SELECT  c.id, c.income, sum_claim
FROM client c
JOIN TotalClaims tc ON c.id = tc.client_id
WHERE tc.sum_claim > 0.5*c.income;

-- Ex.5 solution
WITH TotalClaimsPerClient AS (
  SELECT
    client_id,
    SUM(claim_amt) AS total_claims
  FROM claim
  GROUP BY client_id
)
SELECT
  c.id AS client_id,
  c.income,
  t.total_claims
FROM client c
JOIN TotalClaimsPerClient t
  ON c.id = t.client_id
WHERE t.total_claims > 0.5 * c.income;

