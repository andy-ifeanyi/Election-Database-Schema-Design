
SET SEARCH_PATH TO parlgov;
drop table if exists q3 cascade;

-- You must not change this table definition.

create table q3(
country VARCHAR(50), 
num_dissolutions INT,
most_recent_dissolution DATE,
num_on_cycle INT,
most_recent_on_cycle DATE
);


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



create view country_elections as
        select election.country_id, election.id, election.e_date
        from election join country
                on country.id=election.country_id
        order by country_id, e_date;

create view everythingElse as
        select c2.country_id, c2.id as electionID, c2.e_date
        from country_elections as c2 join country_elections as c1
                on c2.country_id = c1.country_id and c2.e_date > c1.e_date
        order by country_id, e_date;

create view first as
        select * from (select * from country_elections except select * from everythingElse) as first;

create view first_election as
        select c.country_id, c.id as election_id, c.e_date, f.e_date as first_date
        from country_elections as c join first as f
                on c.country_id=f.country_id
        order by country_id, e_date;

create view cycle as
        select f.country_id, f.election_id, f.e_date, f.first_date, c.election_cycle
        from first_election as f join country as c
                on f.country_id=c.id
        order by country_id, e_date;


create view count1 as
        select cycle.country_id, cycle.election_id, cycle.e_date, (date_part('year', e_date)-date_part('year', first_date)) as year_diff, cycle.election_cycle
        from cycle
        order by country_id, e_date;

create view row_num as select *, row_number() over (partition by country_id order by country_id) as country_rows, row_number() over() as rows from count1 order by country_id, e_date;
create view row_val as select *, nth_value(e_date, (rows+1)::int4) over () as next from row_num;
create view year_diff as select *, date_part('year', next)-date_part('year', e_date) as difference from row_val;
create view lag as select *, lag(difference, 1) over () from year_diff;


-- finding the election in cycles
create view in_cyc as 
	select * from lag where lag-election_cycle=0 or year_diff=0;

-- find distinct winners, with distinct election
-- every data right now should be unique; if not select distinct to get rid of the others 
create view distinct_winners as
        select distinct * from election_winners;


create view sorted_winners as
	select distinct_winners.countryID, party.name, party.id as partyID, e_date, distinct_winners.election_id as now_Id 
	from election join distinct_winners on distinct_winners.election_id = election.id join party on party.id = distinct_winners.party_id
	order by distinct_winners.countryID DESC, party.name, e_date;


-- opposite to the above ^ 
create view out_cyc as 
	select * from lag where lag<election_cycle;


create view stats_in as
        select country_id, count(*) as num, max(e_date) as most_recent
        from out_cyc
        group by country_id;


-- I am getting a count of streaks 
-- using row_num (), I can numerize respective streaks

create view counter as
	select countryID, name, partyID, e_date,
	ROW_NUMBER () over (
	partition by partyID
	order by e_date)
	from sorted_winners order by countryid desc, e_date; 


create view stats_out as
        select country_id, count(*) as num, max(e_date) as most_recent
        from in_cyc
        group by country_id;

create view on_off as
        select stats_out.country_id, stats_in.num as off_num, stats_in.most_recent as recent_off, stats_out.num as on_num, stats_out.most_recent as recent_on
        from stats_in join stats_out on stats_in.country_id=stats_out.country_id;

create view final_ans as
        select country.name as country, on_off.off_num as off_num, on_off.recent_off as recent_off, on_off.on_num as on_num, on_off.recent_on as recent_on
        from on_off join country on country.id=on_off.country_id
        order by country_id;

-- the answer to the query 
insert into q3 select * from final_ans;

