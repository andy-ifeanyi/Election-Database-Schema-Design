SET SEARCH_PATH TO parlgov;
drop table if exists q1 cascade;

-- You must not change this table definition.

create table q1(
century VARCHAR(2),
country VARCHAR(50), 
left_right REAL, 
state_market REAL, 
liberty_authority REAL
);


-- You may find it convenient to do this for each of the views
-- that define your intermediate steps.  (But give them better names!)
--DROP VIEW IF EXISTS intermediate_step CASCADE;

-- Define views for your intermediate steps here.

-- find winners (given)
create  view  election_winners  as
select  election.id as  election_id , cabinet_party.party_id
from  election  join  cabinet
on  election.id = cabinet.election_id
join  cabinet_party
on  cabinet.id = cabinet_party.cabinet_id
where  cabinet_party.pm = true;


-- get the first two centuries
--find the 20th century
-- found method of casting through online resources

create view twenty_century as
	select election.id , election.e_date
	from election where (cast(e_date as text) LIKE '19%' OR cast(e_date as text) LIKE '2000%') and not cast(e_date as text) LIKE '1900%' ;

-- find rhe 21st century 
create view twenty_one_century as
	select election.id,  election.e_date
	from election where (cast(e_date as text) LIKE '20%' OR cast(e_date as text) LIKE '2100%') and not cast(e_date as text) LIKE '2000%';

-- get all the alliance ids 
-- alliance id <> NULL = head id
create view alliance_not_null as
select election_id, party_id, alliance_id
from election_result where alliance_id is not NULL;

-- Get the head ids
create view alliance_null as
	select election_id, party_id, id as alliance_id 
	from election_result  where alliance_id is NULL;

-- put them together to find all the all the winners
create view append_new_alliance as
(select * from alliance_null) union all (select * from alliance_not_null);


-- find all the winners 
-- find the description of all the winners

create view winners as
select a.election_id, a.party_id, a.alliance_id
from election_winners as w join append_new_alliance as a
on (w.election_id = a.election_id and w.party_id = a.party_id);


-- avg values required for each alliance
-- as defined by questions
create view avg_alliance as
select a.alliance_id, avg (left_right) as left_right, avg(state_market) as state_market, avg(liberty_authority) as liberty_authority
from append_new_alliance as a join party_position as pp on (a.party_id = pp.party_id)
group by a.alliance_id;


-- election 
-- find all the election details as required 
create view election_average as
select w.election_id, w.alliance_id, left_right,state_market,liberty_authority
from winners as w join avg_alliance as aa on (w.alliance_id = aa.alliance_id)
ORDER BY w.alliance_id;



-- find elections from 20th centry
create view election_twenty as
select e.election_id, e.left_right, e.state_market, e.liberty_authority
from election_average as e join twenty_century as tc on (e.election_id = tc.id);


-- find country with elections' country from 20th century 
create view election_country_twenty as
select t0.election_id, e.country_id, t0.left_right, t0.state_market,t0.liberty_authority
from election_twenty as t0 join election as e on (t0.election_id = e.id);


--^ Same thing as above. Find the elections from the 21st Century
create view election_twenty_one as
select e.election_id, e.left_right, e.state_market, e.liberty_authority
from election_average as e join twenty_one_century as toc on (e.election_id = toc.id);

-- country 21
create view election_country_twenty_one as
select t1.election_id, e.country_id, t1.left_right, t1.state_market, t1.liberty_authority
from election_twenty_one as t1 join election as e on (t1.election_id = e.id);



--Calculate avg for country per century

create view twenty as
	select 20 as century, country_id, avg (left_right) as left_right, avg(state_market) as state_market, avg(liberty_authority) as liberty_authority
	from election_country_twenty
	group by country_id;

create view twenty_one as
	select 21 as century, country_id, avg (left_right) as left_right, avg(state_market) as state_market, avg(liberty_authority) as liberty_authority
	from election_country_twenty_one
	group by country_id;



create view total_country as
(select * from twenty) union all (select * from twenty_one);

create view total_country_avg as
select t.century as century, c.name as country, t.left_right as left_right, t.state_market as state_market, t.liberty_authority as liberty_authority
from total_country as t join country as c on (t.country_id = c.id);


-- the answer to the query 
insert into q1 select * from total_country_avg;
