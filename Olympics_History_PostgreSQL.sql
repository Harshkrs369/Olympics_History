--1. How many olympics games have been held?

select count(distinct games) as total_games from olympics_history;

--2. List down all Olympics games held so far.

select distinct year,season,city from olympics_history
order by year;

--3. Mention the total no of nations who participated in each olympics game?

select distinct games, count(distinct ohnr.region) as total_countries from olympics_history oh
join olympics_history_noc_regions ohnr on oh.noc=ohnr.noc
group by oh.games;

--4. Which year saw the highest and lowest no. of countries participating in olympics?

with t1 as(select distinct games, count(distinct ohnr.region) as total_countries from olympics_history oh
join olympics_history_noc_regions ohnr on oh.noc=ohnr.noc
group by oh.games)
select distinct
concat(first_value(games) over(order by total_countries),'-',first_value (total_countries) over(order by total_countries)) as lowest_countries,
concat(first_value(games) over(order by total_countries desc),'-',first_value (total_countries) over(order by total_countries desc)) as highest_countries
from t1
order by 1;

--5. Which nation has participated in all of the olympic games?

with tot_games as
	(select count(distinct games) as total_games from olympics_history),
countries as 
	(select games,ohnr.region as country from olympics_history oh
	join olympics_history_noc_regions ohnr on ohnr.noc=oh.noc
	group by oh.games,ohnr.region),
countries_participated as
	(select country, count(1) as participated_games 
	from countries
	group by country)
select cp.* from countries_participated cp
join tot_games tg on total_games=participated_games
order by 1;

--6. Identify the sport which was played in all summer olympics.

with t1 as(
	select count(distinct games) as total_games
	from olympics_history oh 
	where season='Summer'
),
t2 as (
	select distinct games,sport from olympics_history where season='Summer'
),
t3 as (
	select sport, count(1) as no_of_games from (select distinct games,sport from olympics_history where season='Summer')
	group by sport
)
select * from t3
join t1 on t1.total_games=t3.no_of_games;

--7. Which Sports were just played only once in the olympics.

with t1 as (
	select distinct games, sport from olympics_history
),
t2 as (select sport, count(sport) as no_of_games from t1
	group by sport)
select t2.*,t1.games
from t2
join t1 on t2.sport=t1.sport
where no_of_games=1
order by sport;

--8. Fetch the total no of sports played in each olympic games.

with t1 as(
	select distinct games,sport from olympics_history
),
t2 as(
	select games, count (games) as no_of_sports from (select distinct games,sport from olympics_history)
group by games)
select * from t2
order by no_of_sports asc;

--9. Find the Ratio of male and female athletes participated in all olympic games.

with t1 as (
	select sex,count(1) as cnt
	from olympics_history
	group by sex
),
t2 as (
	select *, row_number() over(order by cnt) as rn
	from t1),
min_cnt as (
	select cnt from t2
	where rn=1
),
max_cnt as(
	select cnt from t2
	where rn=2
)
select concat('1 : ',round(max_cnt.cnt::decimal/min_cnt.cnt,2))as ratio
	from min_cnt,max_cnt;


--10. Fetch the top 5 athletes who have won the most gold medals.

with t1 as(
	select name, team, count(1)as total_gold_medals
	from olympics_history
	where medal='Gold'
	group by team, name
	order by total_gold_medals desc
),
t2 as(
	select *, dense_rank() over(order by total_gold_medals desc) as rnk
	from t1
)
select name, team,total_gold_medals, rnk
from t2
where rnk<6;

--11. Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won.

with t1 as(
	select * from olympics_history oh
join olympics_history_noc_regions ohnr on oh.noc=ohnr.noc
order by ohnr.noc),
t2 as(
	select region as country, count(1) as total_medals
	from t1
	where medal in ('Gold','Silver','Bronze')
	group by country
	order by total_medals desc
),
t3 as (
	select *, dense_rank() over(order by total_medals desc) as rnk
	from t2
)
select * from t3 
where rnk<6;

--12. List down total gold, silver and bronze medals won by each country.

select country,
coalesce(gold,0)as gold,
coalesce(silver,0)as silver,
coalesce(bronze,0)as bronze

from crosstab(
	'select ohnr.region as country, medal, count(1) as total_medals
from olympics_history oh
join olympics_history_noc_regions ohnr on ohnr.noc=oh.noc
where medal <>''NA''	
group by ohnr.region,medal
order by ohnr.region,medal',
'values(''Bronze''),(''Gold''),(''Silver'')')
as final_result(country varchar, bronze bigint, gold bigint, silver bigint)
order by gold desc, silver desc, bronze desc;

--13. Identify which country won the most gold, most silver and most bronze medals in each olympic games.

with t1 as(select substring(games_country,1,position('-'in games_country)-1)as games,
substring(games_country,position('-'in games_country)+1)as country,
coalesce(gold,0)as gold,
coalesce(silver,0)as silver,
coalesce(bronze,0)as bronze

from crosstab(
	'select concat(games,''-'',ohnr.region) as games_country, medal, count(1) as total_medals
from olympics_history oh
join olympics_history_noc_regions ohnr on ohnr.noc=oh.noc
where medal <>''NA''	
group by games_country,medal
order by games_country,medal',
'values(''Bronze''),(''Gold''),(''Silver'')')
as final_result(games_country varchar, bronze bigint, gold bigint, silver bigint)
order by games_country)

select distinct games,
	concat(first_value(country)over(partition by games order by gold desc),
	'-',first_value(gold)over(partition by games order by gold desc)) as max_gold,

	concat(first_value(country)over(partition by games order by silver desc),
	'-',first_value(silver)over(partition by games order by silver desc)) as max_silver,

	concat(first_value(country)over(partition by games order by bronze desc),
	'-',first_value(bronze)over(partition by games order by bronze desc)) as max_bronze
	from t1
	order by games;

--14. In which Sport/event, India has won highest medals.

with t1 as(
	select sport,count(1)as total_medals
	from olympics_history
	where medal <>'NA'
	and team='India'
	group by sport
	order by total_medals desc
),
t2 as (
	select *,rank() over(order by total_medals desc) as rnk
	from t1)
select sport, total_medals from t2
where rnk =1;

--15. Break down all olympic games where India won medal for Hockey and how many medals in each olympic games

select team,sport,games,count(1)as total_medals
	from olympics_history
	where medal <>'NA'
	and team='India' and sport='Hockey'
group by team,sport,games
order by total_medals desc;