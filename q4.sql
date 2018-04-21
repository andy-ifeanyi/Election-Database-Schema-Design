SET SEARCH_PATH TO parlgov;
drop table if exists q4 cascade;

-- You must not change this table definition.


CREATE TABLE q4(
country VARCHAR(50),
num_elections INT,
num_repeat_party INT,
num_repeat_pm INT
);



CREATE VIEW election_winners AS
SELECT DISTINCT election.id as election_id, cabinet_party.party_id
FROM election JOIN cabinet
		ON election.id = cabinet.election_id
	JOIN cabinet_party
		ON cabinet.id = cabinet_party.cabinet_id
WHERE cabinet_party.pm = true;


CREATE VIEW elec_num AS
	SELECT coun.name as country, count(coun.name) as elec_num
	FROM election as elec JOIN country as coun ON elec.country_id = coun.id WHERE elec.e_type = 'Parliamentary election' GROUP BY coun.name;

create view country_elections as
        select election.country_id, election.id, election.e_date
        from election join country
                on country.id=election.country_id
        order by country_id, e_date;


CREATE VIEW pm_elec AS
	SELECT DISTINCT election.id as election_id, cabinet_party.party_id, regexp_replace(cabinet.name::text, '([A-Za-z]*?)[ IV]+$', '\1') as name
	FROM election JOIN cabinet ON election.id = cabinet.election_id JOIN cabinet_party ON cabinet.id = cabinet_party.cabinet_id WHERE cabinet_party.pm = true;

CREATE VIEW winning_pm AS
	SELECT coun.name AS country, pm_elec.election_id, elec.previous_parliament_election_id, elec.e_date, pm_elec.party_id, pm_elec.name
	FROM election as elec JOIN pm_elec 
	ON pm_elec.election_id = elec.id JOIN country as coun ON elec.country_id = coun.id;

-- find distinct winners, with distinct election
-- every data right now should be unique; if not select distinct to get rid of the others 
create view distinct_winners as
	select distinct * from election_winners;


CREATE VIEW w_parties AS
	SELECT coun.name AS country, w.election_id, e.previous_parliament_election_id, e.e_date, w.party_id
	FROM election as e JOIN election_winners as w ON w.election_id = e.id JOIN country as coun ON e.country_id = coun.id;

-- get all the alliance ids 
create view alliance_not_null as
select election_id, party_id, alliance_id
from election_result where alliance_id is not NULL;

CREATE VIEW repeat_party AS
	SELECT w1.country, count(w1.country) as repeat_party FROM w_parties as w1 JOIN w_parties as w2 ON w1.country = w2.country WHERE w1.election_id = w2.previous_parliament_election_id AND w1.party_id = w2.party_id
	GROUP BY w1.country;


CREATE VIEW repeat_pms AS
	SELECT DISTINCT w1.country, w1.name
	FROM winning_pm as w1 JOIN winning_pm as w2 ON w1.country = w2.country
	WHERE w1.election_id > w2.election_id AND w1.name = w2.name;


CREATE VIEW num_pm AS
	SELECT country, count(country) as num_pm
	FROM repeat_pms
	GROUP BY country;

-- the answer to the query 
insert into q4 

	SELECT n1.country, n1.elec_num as num_elections, n2.repeat_party as num_repeat_party, n3.num_pm as num_repeat_pm
	FROM elec_num n1 JOIN repeat_party n2 ON n1.country = n2.country JOIN num_pm n3 ON n2.country = n3.country
	ORDER BY n1.country;
