SET SEARCH_PATH TO parlgov;
drop table if exists q5 cascade;

-- You must not change this table definition.

CREATE TABLE q5(
electionId INT,
countryName VARCHAR(50),
winningParty VARCHAR(100),
closeRunnerUp VARCHAR(100)
);

-- You may find it convenient to do this for each of the views
-- that define your intermediate steps.  (But give them better names!)
DROP VIEW IF EXISTS intermediate_step CASCADE;

-- Overall picture: Get all the winners for all elections
-- Join that with election_result on election id
-- Then select the rows where winner votes * 0.9 < the other party / alliance (head)

-- Define views for your intermediate steps here.

-- Get all of the winning parties based on the cabinet
create view election_winners as
select distinct election.id as election_id , cabinet_party.party_id from election join cabinet
on election.id = cabinet.election_id join cabinet_party
on cabinet.id = cabinet_party.cabinet_id where cabinet_party.pm = true;

create view head_of_alliance as
select distinct election_result.election_id, election_result.party_id, election_result.id as alliance_id, election_result.votes
from election_result
where alliance_id is NULL;

create view not_head_of_alliance as
select distinct election_result.election_id, election_result.party_id, election_result.alliance_id, election_result.votes
from election_result
where alliance_id is not NULL;

create view election_alliance as
SELECT *
FROM
head_of_alliance
UNION
SELECT *
FROM
not_head_of_alliance;

-- Aggregate all alliance votes for all elections
create view election_alliance_sum as
select distinct election_alliance.election_id as election_id, election_alliance.alliance_id, sum(election_alliance.votes) as total_votes
from election_alliance
group by election_alliance.election_id, election_alliance.alliance_id;

-- get winner alliances
create view winner_alliances as
select distinct election_alliance.alliance_id, election_winners.election_id
from election_alliance, election_winners
where election_winners.election_id = election_alliance.election_id and election_winners.party_id = election_alliance.party_id;

-- use alliance and election_id to get total_votes
create view winner_alliances_total_votes as
select distinct election_alliance_sum.election_id as election_id, winner_alliances.alliance_id as alliance_id, election_alliance_sum.total_votes as total_votes
from winner_alliances join election_alliance_sum on winner_alliances.election_id = election_alliance_sum.election_id
where winner_alliances.alliance_id = election_alliance_sum.alliance_id;

-- Runner ups are all the alliance_sum whose votes are 0.9 that of the winner_alliance_sum
create view multi_runners as
select distinct election_alliance_sum.alliance_id as closeRunnerUp, winner_alliances_total_votes.alliance_id as Winner,
election_alliance_sum.total_votes as RunnerUpVotes, winner_alliances_total_votes.total_votes as WinnerVotes, election_alliance_sum.election_id as election_id
from winner_alliances_total_votes join election_alliance_sum
on election_alliance_sum.alliance_id <> winner_alliances_total_votes.alliance_id and election_alliance_sum.election_id = winner_alliances_total_votes.election_id
where election_alliance_sum.total_votes > 0.9 * winner_alliances_total_votes.total_votes and election_alliance_sum.total_votes < winner_alliances_total_votes.total_votes
ORDER BY election_alliance_sum.total_votes;

create view no_dups_runner_ups as
select multi_runners.election_id, max(multi_runners.RunnerUpVotes)
from multi_runners
group by multi_runners.election_id;

-- 28 elements
create view runner_ups as
select multi_runners.election_id
from multi_runners inner join no_dups_runner_ups on multi_runners.election_id = no_dups_runner_ups.election_id
group by multi_runners.election_id;

create view get_Runnerup_id as
select distinct election_result.party_id as party_id, runner_ups.election_id as election_id
from election_result, runner_ups, multi_runners
where election_result.id = multi_runners.closeRunnerUp and election_result.election_id = runner_ups.election_id;

create view get_Runnerup as
select party.name as name, get_Runnerup_id.election_id as election_id
from party, get_Runnerup_id
where party.id = get_Runnerup_id.party_id;

create view get_Winner_id as
select distinct election_result.party_id as party_id, runner_ups.election_id as election_id
from election_result, runner_ups, multi_runners
where election_result.id = multi_runners.Winner and election_result.election_id = runner_ups.election_id;

create view get_Winner as
select party.name as name, get_Winner_id.election_id as election_id
from party, get_Winner_id
where party.id = get_Winner_id.party_id;

create view get_Country_id as
select party.country_id as country_id, party.id as party_id, get_Winner_id.election_id as election_id
from party, get_Winner_id
where party.id = get_Winner_id.party_id;

create view get_Country as
select country.name as country_name, get_Country_id.election_id as election_id
from get_Country_id, country, party
where country.id = get_Country_id.country_id and party.id = get_Country_id.party_id;

create view ans as
select distinct no_dups_runner_ups.election_id as electionID,
get_Winner.name as winningParty, get_Runnerup.name as closeRunnerUp
from no_dups_runner_ups, get_Winner, get_Runnerup
where get_Runnerup.election_id = get_Winner.election_id and no_dups_runner_ups.election_id = get_Runnerup.election_id
and get_Winner.election_id = no_dups_runner_ups.election_id;

create view ans1 as
select distinct no_dups_runner_ups.election_id as electionID,
get_Winner.name as winningParty
from no_dups_runner_ups
inner join get_Winner on no_dups_runner_ups.election_id = get_Winner.election_id
ORDER BY no_dups_runner_ups.election_id;

create view ans2 as
select distinct ans1.electionID as electionID, ans1.winningParty as winningParty, get_Runnerup.name as closeRunnerUp
from ans1
inner join get_Runnerup on ans1.electionID = get_Runnerup.election_id
ORDER BY ans1.electionID;

create view ans3 as
select distinct ans2.electionID as electionID, get_Country.country_name as countryName, ans2.winningParty as winningParty, ans2.closeRunnerUp as closeRunnerUp
from ans2
inner join get_Country on ans2.electionID = get_Country.election_id
ORDER BY ans2.electionID;

insert into q5 (select * from ans3);

-- the answer to the query