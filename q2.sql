SET SEARCH_PATH TO parlgov;
drop table if exists q2 cascade;
-- You must not change this table definition.

create table q2(
country VARCHAR(50),
electoral_system VARCHAR(100),
single_party INT,
two_to_three INT,
four_to_five INT,
six_or_more INT
);


-- You may find it convenient to do this for each of the views
-- that define your intermediate steps.  (But give them better names!)
-- Define views for your intermediate steps here

-- get the election winners - they make up the government. They can either be in an alliance,
-- is the alliance head or is a single_party.

-- given winners
create view election_winners as 
	select election.country_id, election.id as election_id, cabinet_party.party_id
	from election join cabinet
		on election.id = cabinet.election_id
	join cabinet_party
		on cabinet.id = cabinet_party.cabinet_id
	where e_type = 'Parliamentary election' and cabinet_party.pm = true;

-- find distinct winners, with distinct election
-- every data right now should be unique; if not select distinct to get rid of the others 
create view distinct_winners as
	select distinct * from election_winners;


-- find the winner id with e_results 
create view winner as
	select country_id, ew.election_id as eid, er.id as er_id, alliance_id
	from election_winners as ew left join election_result as er 
		on ew.election_id = er.election_id  
		and ew.party_id = er.party_id;
	
create view info as
	select c.name as country, w.country_id, c.electoral_system
	from country as c right join winner as w
	on c.id = w.country_id
	left join election as e
	on w.eid = e.id and w.country_id = e.country_id ;


-- finding all the head_ids where alliance = NULL

create view head_id as 
	select er_id, eid, country_id
	from winner
	where alliance_id is null;
 
-- add all the alliance and winners together
create view winner_alliance as
	select * from head_id
	union all
	(select alliance_id as er_id, eid, country_id
	from winner where alliance_id is not null);


-- sort by country descending, party_ID and their e_dates
-- need to do this step as I am calling row_num() after this and row_num() aggregates partitions
-- every winner right now should be sorted based on their respective country IDs and party IDs


create view sorted_winners as
	select distinct_winners.country_id, party.name, party.id as partyID, e_date, distinct_winners.election_id as now_Id 
	from election join distinct_winners on distinct_winners.election_id = election.id join party on party.id = distinct_winners.party_id
	order by distinct_winners.country_id DESC, party.name, e_date;

-- alliances with different parties 
create view party_1 as 
	select country_id, count(*) as single_party
	from winner_alliance
	where (select count(*) 
		from election_result 
		where (winner_alliance.er_id = election_result.id and election_result.alliance_id is NULL) or 
			(election_result.alliance_id = winner_alliance.er_id)) = 1 
	group by country_id;

create view party2_3 as 
	select country_id, count(*) as two_to_three 
	from winner_alliance
	where (select count(*) 
		from election_result 
		where (winner_alliance.er_id = election_result.id and election_result.alliance_id is NULL) or 
			(election_result.alliance_id = winner_alliance.er_id)) = 2 
		or 
		(select count(*)
		from election_result e1
		where (winner_alliance.er_id = e1.id and e1.alliance_id is NULL) or 
			(e1.alliance_id = winner_alliance.er_id)) = 3  
	group by country_id;

create view party4_5 as	
	select country_id, count(*) as four_to_five 
	from winner_alliance
	where (select count(*) 
		from election_result 
		where (winner_alliance.er_id = election_result.id and election_result.alliance_id is NULL) or 
			(election_result.alliance_id = winner_alliance.er_id)) = 4
		or
		(select count(*)
		from election_result
		where (winner_alliance.er_id = election_result.id and election_result.alliance_id is NULL) or 
			(election_result.alliance_id = winner_alliance.er_id)) = 5 
	group by country_id;

create view party_6_plus as 
	select country_id, count(*) as six_or_more 
	from winner_alliance
	where (select count(*) 
		from election_result 
		where (winner_alliance.er_id = election_result.id and election_result.alliance_id is NULL) or 
			(election_result.alliance_id = winner_alliance.er_id)) >=6 
	group by country_id;


-- the answer to the query 
insert into q2 
	select distinct country, electoral_system, coalesce(single_party,0) as single_party, coalesce(two_to_three,0) as two_to_three, 
		coalesce(four_to_five,0) as four_to_five, coalesce(six_or_more,0) as six_or_more
	from info full join party_1 on info.country_id = party_1.country_id
	full join party2_3 on info.country_id = party2_3.country_id
	full join party4_5 on info.country_id = party4_5.country_id
	full join party_6_plus on info.country_id = party_6_plus.country_id;