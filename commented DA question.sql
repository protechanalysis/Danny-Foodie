-- 1. How many customers has Foodie-Fi ever had?
-- Count the number of distinct customer_id in the 'subscriptions' table.
select count(distinct customer_id) as num_customer
from subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset? Use the start of the month as the group by value.
-- Count the number of occurrences of trial plan start_date values in each month.
select monthname(start_date) as month, count(start_date) as num
from subscriptions
where plan_id = 0
group by month
order by num desc;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name.
-- Count the occurrences of each plan_name whose start_date is after the year 2020.
select plan_name, count(s.plan_id) as num_occurrence 
from subscriptions as s
inner join plans
using(plan_id)
where year(start_date) > 2020
group by plan_name
order by num_occurrence desc;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
-- Calculate the number and percentage of customers who have churned (plan_id = 4) as well as the total number of customers.
select num_churn, round(num_churn/total_customer * 100,1) as churn_rate
from (
  -- Subquery to count the number of distinct customer_id who have churned.
  select count(distinct customer_id) num_churn
  from subscriptions
  where plan_id = 4
) as c, (
  -- Subquery to get the total number of customers.
  select count(*) as total_customer
  from subscriptions
) as s;

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number.
-- Calculate the number and percentage of customers who churned (plan_id = 4) exactly 7 days after their initial free trial (plan_id = 0).
with churn as (
  -- Subquery to identify the churned customers and calculate the duration between trial start_date and churn_date.
  select t.customer_id, t.plan_id as t, a.plan_id, t.start_date, churn_date, datediff(churn_date, t.start_date) as duration
  from subscriptions as t
  left join (
    select customer_id, plan_id, start_date as churn_date
    from subscriptions
  ) as a 
  using(customer_id)
  where a.plan_id = 4 and t.plan_id = 0 
  having(duration) = 7
)
select count(duration) as num_churn_after_trial, round(count(duration) * 100 /(select count(customer_id) from subscriptions)) as churn_after_trial_rate
from churn;

-- 6. What is the number and percentage of customer plans after their initial free trial?
-- Count the number and percentage of plans (excluding trial and churned plans) taken by customers after their initial free trial.
with sub as (
	select *, rank() over (PARTITION BY customer_id ORDER BY start_date) as ranking from subscriptions inner join plans using(plan_id))
select plan_name, count(plan_id) as num_plans, 
	count(plan_id)*100/(select count(customer_id) from sub where ranking = 2) as percent_plan
from sub
where ranking = 2
group by plan_name;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
-- Calculate the customer count and percentage breakdown for each plan_name at the specified date.
with sub as (select *, rank() over (PARTITION BY customer_id ORDER BY start_date desc) as ranking 
			from subscriptions inner join plans using(plan_id) where start_date <= '2020-12-31')
select plan_name, count(distinct customer_id) as num_customer, 
	count(distinct customer_id)*100/(select count(customer_id) from sub where ranking = 1) as percent_plan
from sub
where ranking = 1
group by plan_name;

-- 8. How many customers have upgraded to an annual plan in 2020?
-- Count the number of customers who have upgraded to an annual plan (plan_id = 3) in the year 2020.
select count(plan_id)
from subscriptions
where plan_id = 3 and year(start_date) = 2020;

-- 9. How many days on average does it take for a customer to upgrade to an annual plan from the day they join Foodie-Fi?
-- Calculate the average number of days for customers to upgrade from the initial free trial (plan_id = 0) to an annual plan (plan_id = 3).
select avg(datediff(d, f)) as avg_day
from  (
  -- Subquery to get the initial start_date for customers on the trial plan.
  select customer_id, min(start_date) as f 
  from subscriptions where plan_id = 0 
  group by customer_id
) as n,
(
  -- Subquery to get the start_date for customers on the annual plan.
  select customer_id, min(start_date) as d 
  from subscriptions where plan_id = 3 
  group by customer_id
) as t
where n.customer_id = t.customer_id;

-- 10. Can you further breakdown this average value into 30-day periods (i.e. 0-30 days, 31-60 days, etc)?
-- Further breakdown the average number of days into 30-day periods for customers to upgrade to an annual plan.
select  avg(case when datediff(d, f) between 0 and 30 then  datediff(d, f) end) as '0-30 days avg',
	avg(case when datediff(d, f) between 31 and 60 then  datediff(d, f) end) as '31-60 days avg',
    avg(case when datediff(d, f) between 61 and 90 then  datediff(d, f) end) as '61-90 days avg',
    avg(case when datediff(d, f) > 90 then datediff(d, f) end) as 'over 90 days'
from  (
  -- Subquery to get the initial start_date for customers on the trial plan.
  select customer_id, min(start_date) as f 
  from subscriptions where plan_id = 0 
  group by customer_id
) as n,
(
  -- Subquery to get the start_date for customers on the annual plan.
  select customer_id, min(start_date) as d 
  from subscriptions where plan_id = 3 
  group by customer_id
) as t
where n.customer_id = t.customer_id;

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
-- Count the number of customers who downgraded from a pro monthly plan (plan_id = 2) to a basic monthly plan (plan_id = 1) in the year 2020.
with pro_mon as (
  -- Subquery to get the start_date for customers on the pro monthly plan in 2020.
  select customer_id, start_date as pro_month_date
  from subscriptions
  where plan_id = 2 and year(start_date) = 2020
),
bmon as (
  -- Subquery to get the start_date for customers on the basic monthly plan in 2020.
  select customer_id, start_date as basic_month_date
  from subscriptions
  where plan_id = 1 and year(start_date) = 2020
)
select count(*) as num_downgrade
from pro_mon
inner join bmon
using(customer_id)
where pro_month_date < basic_month_date;
