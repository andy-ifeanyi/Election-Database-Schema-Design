SET SEARCH_PATH TO parlgov;
drop table if exists q6 cascade;

-- You must not change this table definition.

CREATE TABLE q6(
countryId INT,
partyName VARCHAR(10),
number INT
);

-- You may find it convenient to do this for each of the views
-- that define your intermediate steps.  (But give them better names!)
DROP VIEW IF EXISTS intermediate_step CASCADE;

-- Define views for your intermediate steps here.

-- get all of the winning parties based on the cabinet
create view election_winners as
select election . id as election_id , cabinet_party . party_id, country.id as countryID
from election join cabinet
on election . id = cabinet . election_id
join cabinet_party
on cabinet . id = cabinet_party . cabinet_id
join country
on cabinet . country_id = country . id
where cabinet_party . pm = true ;


-- find distinct winners, with distinct election
-- every data right now should be unique; if not select distinct to get rid of the others 
create view distinct_winners as
	select distinct * from election_winners;

-- sort by country descending, party_ID and their e_dates
-- need to do this step as I am calling row_num() after this and row_num() aggregates partitions
-- every winner right now should be sorted based on their respective country IDs and party IDs


create view sorted_winners as
	select distinct_winners.countryID, party.name, party.id as partyID, e_date, distinct_winners.election_id as now_Id 
	from election join distinct_winners on distinct_winners.election_id = election.id join party on party.id = distinct_winners.party_id
	order by distinct_winners.countryID DESC, party.name, e_date;

-- I am getting a count of streaks 
-- using row_num (), I can numerize respective streaks

create view counter as
select countryID, name, partyID, e_date,
ROW_NUMBER () over (
partition by partyID
order by e_date)
from sorted_winners order by countryid desc, e_date; 


-- take the max streak per party
-- I should have all the max_num of streaks observed/party
create view max_counter_party as
	select countryID, party.name_short, max(row_number) 
	 from counter, party 
	 where party.id = counter.partyID 
	 group by countryID, party.name_short 
	 order by countryID desc;

 -- I can get the max streaks per country

create view max_counter_country_party as 
	select countryID, max(max) 
	from max_counter_party 
	group by countryID;


-- this query should allow me to get all the respective party_ids with the max count
-- this should also consider duplicates
-- the answer to the query 

insert into q6 select max_counter_country_party.countryid as countryID, name_short as partyName, max_counter_country_party.max as number 
from max_counter_country_party, max_counter_party 
where max_counter_country_party.max = max_counter_party.max;