SET SEARCH_PATH TO parlgov;
drop table if exists q7 cascade;

-- You must not change this table definition.

DROP TABLE IF EXISTS q7 CASCADE;
CREATE TABLE q7(
partyId INT, 
partyFamily VARCHAR(50) 
);

-- You may find it convenient to do this for each of the views
-- that define your intermediate steps.  (But give them better names!)
DROP VIEW IF EXISTS intermediate_step CASCADE;

-- Define views for your intermediate steps here.
-- q7 starts here

-- create the view of a winning party
-- find parliamentary elec. winners 
create view parliamentary_election_winners as
select election.id as election_id , cabinet_party.party_id, e_date
from election join cabinet
on election.id = cabinet.election_id
join cabinet_party
on cabinet.id = cabinet_party.cabinet_id
where cabinet_party.pm = true and e_type =  'Parliamentary election'
order by e_date;

-- HERE --

-- distinct winner
create view distinct_parl_winners as select distinct * from parliamentary_election_winners;   

create view distinct_eu as
	select distinct e_date from election where e_type = 'European Parliament'; 

-- get all the EU dates
create view eu_date as
	select e_date as european_date, row_number() over (order by e_date) as european_row from distinct_eu order by e_date;


-- intervals

create view eu_intervals as
	select e2.european_date as IntBegin, e1.european_date as IntEnd from eu_date as e1 join eu_date as e2 on e1.european_row = e2.european_row+1;  


-- winners intervals

create view winners_intervals as 
	select * from distinct_parl_winners as p join eu_intervals as e on (p.e_date >= e.intbegin and p.e_date < e.intend) order by e.intbegin, e.intend;

-- winners before

create view winners_before as 
	select distinct * from distinct_parl_winners as p where p.e_date < (select distinct min(e_date) from election where e_type= 'European Parliament') order by e_date;

create view winners_before_max as
	select distinct party_id, max(e_date) as e_date from winners_before group by party_id;

create view combined_col as
	select * from winners_before_max as w left join eu_intervals as e on (w.e_date > e.intbegin and w.e_date < e.intend);


create view distinct_winner_int as
	select party_id, e_date, intbegin, intend from winners_intervals UNION  ALL select * from combined_col;


-- alliance ids

create view only_winners as 
	select party_id, e_date from distinct_winner_int;


 create view head_ids as 
 	select distinct id, e_date from only_winners as o join election_result as e on o.party_id = e.party_id;

 create view alliance as 
 	select election_id, party_id, e_date from head_ids join election_result on alliance_id = head_ids.id ;


 create view alliance_intervals as 
	select * from alliance as a join eu_intervals as e on (a.e_date >= e.intbegin and a.e_date < e.intend) order by e.intbegin, e.intend;


create view distinct_alliance_int as
	select party_id, e_date, intbegin, intend from alliance_intervals order by party_id, e_date;


-- every winners 
create view every_winner as 
	select * from distinct_winner_int UNION select * from distinct_alliance_int;


create view every_distinct_winner as
	select distinct * from every_winner order by party_id, e_date;


create view all_winners as 
	select party_id, e_date, intbegin, intend from every_distinct_winner;

create view distinct_all_winners as
	select distinct party_id, intbegin, intend from all_winners order by party_id, intbegin, intend;

create view count_eu_int as 
	select count(intbegin) as counteu from eu_intervals;

create view winners_count as 
	select *, row_number() over(partition by party_id order by intbegin) as counter from distinct_all_winners order by party_id, intbegin, intend;

create view winners_max as 
 	select party_id, max(counter) from winners_count group by party_id;

create view family as
	select winners_max.party_id, max, family from winners_max left join party_family on winners_max.party_id = party_family.party_id;
 

create view finalView as 
	select party_id as partyID, family as partyFamily from family join count_eu_int on counteu<=max;


create view finalAnswer as
	select distinct * from finalView;
	

-- the answer to the query 
insert into q7 
	select * from finalAnswer;