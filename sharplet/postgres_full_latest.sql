
-- full 6.6:
BEGIN;

--CREATE LANGUAGE plpgsql;
--
--DROP TABLE IF EXISTS card CASCADE;
--DROP TABLE IF EXISTS deck CASCADE;
--DROP TABLE IF EXISTS users CASCADE;
--DROP TABLE IF EXISTS user_roles CASCADE;
--DROP TABLE IF EXISTS category CASCADE;
--DROP TABLE IF EXISTS deck_stats_basic CASCADE;
--DROP TABLE IF EXISTS my_courses CASCADE;
--DROP TABLE IF EXISTS card_spacing CASCADE;
--DROP TABLE IF EXISTS user_settings CASCADE;
--DROP TABLE IF EXISTS course_comments CASCADE;
--DROP TABLE IF EXISTS category CASCADE;
--
--DROP SEQUENCE IF EXISTS id_sequence CASCADE;
--DROP SEQUENCE IF EXISTS item_longkey_sequence CASCADE;


CREATE TABLE contact(
	id SERIAL PRIMARY KEY,
	user_id integer,
	created TIMESTAMP NOT NULL DEFAULT now(),
	name varchar(64),
	email varchar(64),
	comment varchar(4095),
	ip varchar(64)
);

--CREATE SEQUENCE item_longkey_sequence START WITH 1 INCREMENT BY 1;
--
--CREATE OR REPLACE FUNCTION random_string(length int4) RETURNS varchar AS
--$$
--DECLARE
--iLoop int4;
--result varchar;
--BEGIN
--	result = '';
--	IF (length>0) AND (length < 255) THEN
--		FOR iLoop in 1 .. length LOOP
--			result = result || chr(int4(random()*25)+65);
--		END LOOP;
--		RETURN result || nextval('item_longkey_sequence')::varchar;
--	ELSE
--		RETURN 'f';
--	END IF;
--END;
--$$ LANGUAGE plpgsql;

-- why add salt to hashed pwds?
-- https://www.owasp.org/index.php/Hashing_Java#Why_add_salt_.3F
-- The database is now birthday attack/rainbow crack resistant.
CREATE TABLE users(
	id SERIAL PRIMARY KEY,
	username varchar(64) NOT NULL UNIQUE,
	password varchar(45), -- base64 encoded SHA-256 hashed pwds are 45 length -- fb etc users has no pw
	fname varchar(64),
	lname varchar(64),
	email varchar(64) UNIQUE,
	phone varchar(64),
	fb_id varchar(20),
	fb_locale varchar(8),
	fb_gender varchar(10),
	logins integer NOT NULL DEFAULT 0,
	news boolean NOT NULL DEFAULT false,
	created TIMESTAMP NOT NULL DEFAULT now(),
	tz varchar(64), -- users default timezone
	ip varchar(64) -- at signup
);
CREATE INDEX users_username_idx ON users(username);
CREATE INDEX users_lname_idx ON users(lname);
CREATE INDEX users_email_idx ON users(email);
CREATE INDEX users_fb_id_idx ON users(fb_id);

CREATE TABLE user_roles(
	id SERIAL PRIMARY KEY,
	userkey integer REFERENCES users(id) ON DELETE CASCADE,
	username varchar(64) NOT NULL,
	rolename varchar(20) NOT NULL,
	UNIQUE (username, rolename)
);
-- index?

-- a deck can be in many categories
CREATE TABLE category(
	id SERIAL PRIMARY KEY,
	created TIMESTAMP NOT NULL DEFAULT now(),
	parent integer REFERENCES category(id) ON DELETE CASCADE,
	name varchar(255),
	short_description varchar(255),
	long_description varchar(4095),
	UNIQUE (parent, name)
);
CREATE UNIQUE INDEX category_name_idx ON category(name) WHERE parent IS NULL;
CREATE INDEX category_parent_idx ON category(parent);

-- seldome update decks: split stats into own db
CREATE TABLE deck(
	id SERIAL PRIMARY KEY, -- the world has 130.000.000 books. SERIAL max is 2.147.483.647
	owner integer REFERENCES users(id) ON DELETE CASCADE, -- owner = creator. remove delete cascade later
	author varchar(100), -- name or company or something displayable
	created TIMESTAMP NOT NULL DEFAULT now(),
	updated TIMESTAMP NOT NULL DEFAULT now(),
	
	private boolean NOT NULL DEFAULT true, --private to owner only
	approved boolean NOT NULL DEFAULT false, -- approved by QA
	pending_approve boolean NOT NULL DEFAULT false, -- if true, show deck on admin approval page
	hidden boolean NOT NULL DEFAULT false,
	category integer REFERENCES category(id) ON DELETE SET NULL,
	name varchar(255) NOT NULL,
	url_name varchar(255) UNIQUE, -- lower case name with - instead of spaces, for url mapping, index this one also
	img varchar(255),
	short_description varchar(255),
	long_description varchar(4095),
	size integer NOT NULL default 0, -- nbr cards
	language varchar(20),
	website varchar(60),
	rating real, -- 1-5 mean
	nbr_ratings integer NOT NULL DEFAULT 0,
	nbr_reviews integer  NOT NULL DEFAULT 0,
	icon varchar(60), -- relative URL
	nbr_users integer NOT NULL DEFAULT 0,
	version varchar(10),
	nbr_updates integer NOT NULL DEFAULT 0,
	avg_time_memorize integer NOT NULL DEFAULT 0,	
	price integer NOT NULL DEFAULT 0, -- for now this is the payex price in USD, i.e. $20.00 = 2000
	price_free boolean NOT NULL DEFAULT true,
	UNIQUE (category, name)
);
CREATE INDEX deck_category_idx ON deck(category);
CREATE INDEX deck_owner_idx ON deck(owner);
CREATE INDEX deck_created_idx ON deck(created);
CREATE INDEX deck_url_name_idx ON deck(url_name);

CREATE TABLE card(
	id BIGSERIAL PRIMARY KEY, -- many cards...
	owner integer REFERENCES users(id) ON DELETE CASCADE,
	parent integer REFERENCES deck(id) ON DELETE CASCADE,
	private boolean NOT NULL DEFAULT true, --private to owner only, propagate from deck to all cards on change (on publich to store)
	created TIMESTAMP NOT NULL DEFAULT now(),
	question text,
	answer text,
	hint varchar(255),
	longanswer text,
	ordering real,
	preview boolean,
	rating_type smallint NOT NULL DEFAULT 0, -- 0 = self rating, 1 = MCQ specific choices, 2 = MCQ random choices
	mcqs varchar(610) -- mcq choices for rating_type 1. For simplicity, just a ,-separated string of choices (max 6 with max length 100)
);

CREATE INDEX card_parent_ordering_idx ON card(parent, ordering); -- need btree index for order by

CREATE TABLE course_comments(
	id BIGSERIAL PRIMARY KEY,
	course integer REFERENCES deck(id) ON DELETE CASCADE,
	owner integer REFERENCES users(id) ON DELETE SET NULL,
	comment text NOT NULL,
	rating smallint, -- duplicated from rating in my_courses table
	created TIMESTAMP NOT NULL DEFAULT now(),
	UNIQUE (course, owner) -- or allow many comments per user?
);
CREATE INDEX course_comments_course_id_idx ON course_comments(course);

CREATE TABLE my_courses(
	id BIGSERIAL PRIMARY KEY,
	user_id integer REFERENCES users(id) ON DELETE CASCADE,
	deck_id integer REFERENCES deck(id) ON DELETE CASCADE, 
	hidden boolean NOT NULL DEFAULT false, 
	isowner boolean NOT NULL DEFAULT false,
	rating smallint, -- only set if user has rated the deck
	UNIQUE (user_id, deck_id)
);
CREATE INDEX my_courses_user_id_idx ON my_courses(user_id);

--SET TIMEZONE TO 'UTC';
-- when user adds a deck to "my area", insert all its cards as unseen into card spaceing table
-- http://stackoverflow.com/questions/6151084/which-timestamp-type-to-choose-in-a-postgresql-database
-- Main spacing algorithm storage table
CREATE TABLE card_spacing(
	user_id integer REFERENCES users(id) ON DELETE CASCADE,
	card_id bigint REFERENCES card(id) ON DELETE CASCADE,
	deck_id integer REFERENCES deck(id) ON DELETE CASCADE, -- this is just in case user wants to disable some decks so can filter on this field
	--updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), -- for repeating all todays cards again for example
	--next_time TIMESTAMP WITH TI ME ZONE NOT NULL DEFAULT now(), -- must be in UTC
	updated bigint NOT NULL DEFAULT extract(epoch from now()), -- unix time in seconds (not millis)
	next_time bigint, -- unix time in seconds (not millis), 100000000000 = year 5138
	rep_n integer NOT null default 0, -- repetition number n
	rep_int integer NOT null default 0, -- repetition interval, in days, I
	easyness real NOT null default 1,
	q smallint NOT null default -1, -- the users last response quality q (for repeating low q cards)
	seen smallint NOT NULL DEFAULT 0, -- nbr times seen (ie nbr times answered by the user)
	orig_order real, -- original ordering of cards in deck
	hidden boolean, -- card can be hidden independently of deck when studying
	UNIQUE (user_id, card_id)--, -- use as key in table, reuse (update) rows
	--CHECK(EXTRACT(TIMEZONE FROM next_time) = '0'), -- verify UTC
	--CHECK(EXTRACT(TIMEZONE FROM updated) = '0')
);
CREATE INDEX card_spacing_user_id_idx ON card_spacing(user_id);
CREATE INDEX card_spacing_user_id_next_time_idx ON card_spacing(user_id, next_time);

-- dont want to pollute our spacing table with history data, messes up statistics.
-- so this is for undo functionality.
-- for now only one entry per user here:
CREATE TABLE card_spacing_history(
	user_id integer REFERENCES users(id) ON DELETE CASCADE,
	card_id bigint REFERENCES card(id) ON DELETE CASCADE,
	next_time bigint, -- unix time in seconds (not millis), 100000000000 = year 5138
	rep_n integer NOT null default 0, -- repetition number n
	rep_int integer NOT null default 0, -- repetition interval, in days, I
	easyness real NOT null default 1,
	q smallint NOT null default -1, -- the users last response quality q (for repeating low q cards)
	seen smallint NOT NULL DEFAULT 0, -- nbr times seen (ie nbr times rated)
	UNIQUE (user_id) --for now only keep 1 history entry per user
);
CREATE INDEX card_spacing_history_user_id_idx ON card_spacing_history(user_id);

-- STATISTICS move to dedicated datastore later, maybe add udp etc

--CREATE TABLE deck_stats_global(
--	id SERIAL PRIMARY KEY,
--	parent integer REFERENCES deck(id) ON DELETE CASCADE
--);

--CREATE OR REPLACE FUNCTION insertDeckIntoSpacingTable(userid int, deckid int) RETURNS void AS $$
--    DECLARE
--        curtime timestamp := now();
--    BEGIN
--        INSERT INTO card_spacing(user_id, card_id, deck_id) SELECT userid, id, deckid FROM card WHERE parent=deckid;
--    END;
--$$ LANGUAGE plpgsql;

-- The current state of a deck for a user.
-- Note that all deck might not have entries here, mostly ones that have been studied today, sort of.
CREATE TABLE user_deck_state(
	user_id integer REFERENCES users(id) ON DELETE CASCADE,
	deck_id bigint REFERENCES deck(id) ON DELETE CASCADE,
	updated bigint NOT NULL DEFAULT 0, -- unix time in seconds (not millis) when this entry was written (state is valid for a "day" only, i.e should be reset at 05.00 in the morning in users timezone.
	name varchar(255),
	disabled boolean,
	deleted boolean,
	mfc smallint,
	mnc smallint,
	tbm smallint,
	new_cards_shown smallint NOT NULL DEFAULT 0, -- new cards already shown today
	--failed_card_ids text, -- serialized java list of failed card ids today
	UNIQUE (user_id, deck_id)
);
CREATE INDEX user_deck_state_user_id_idx ON user_deck_state(user_id);
CREATE INDEX user_deck_state_user_id_deck_id_idx ON user_deck_state(user_id, deck_id);

-- This is now a user state storage, for both settings and current user state:
CREATE TABLE user_settings(
	user_id integer REFERENCES users(id) ON DELETE CASCADE,
	max_failed smallint, -- max nbr of failed cards per day per course before showing only failed cards -- max ca 32000
	max_new_day smallint, -- max nbr of new cards to show per course per day
	timebox_min smallint, -- tbd
	study_mode smallint NOT NULL DEFAULT 0, -- 0: single course, 1: study all
--	new_cards_shown_today smallint NOT NULL DEFAULT 0, -- state, reset as per study session?
--	failed_cards_today smallint NOT NULL DEFAULT 0, -- nbr cards you failed so far today (or per current study session, if resetted)
	UNIQUE(user_id)
);
CREATE INDEX user_settings_user_id_idx ON user_settings(user_id);

CREATE TABLE groups(
	id SERIAL PRIMARY KEY,
	created TIMESTAMP NOT NULL DEFAULT now(),
	owner integer REFERENCES users(id) ON DELETE SET NULL,
	private boolean NOT NULL DEFAULT true,
	name varchar(255) NOT NULL,
	description varchar(4095),
	nbrusers integer NOT NULL DEFAULT 0,
	UNIQUE (owner, name)
);
CREATE INDEX groups_name_idx ON groups(name);

CREATE TABLE group_invites(
	id SERIAL PRIMARY KEY,
	created TIMESTAMP NOT NULL DEFAULT now(),
	groupid integer REFERENCES groups(id) ON DELETE CASCADE,
	groupname varchar(255) NOT NULL,
	fromuser integer REFERENCES users(id) ON DELETE CASCADE,
	fromusername varchar(255) NOT NULL,
	touser integer REFERENCES users(id) ON DELETE CASCADE, -- may be null
	toemail varchar(255),  -- may be null
	tousername varchar(255),  -- may be null
	admin boolean,
	UNIQUE (fromuser, groupname, touser),
	UNIQUE (fromuser, groupname, tousername),
	UNIQUE (fromuser, groupname, toemail)
);
CREATE INDEX group_invites_touser_idx ON group_invites(touser);
CREATE INDEX group_invites_toemail_idx ON group_invites(toemail);
CREATE INDEX group_invites_tousername_idx ON group_invites(tousername);

-- mapping of users to groups
CREATE TABLE user_group_mapping(
	groupid integer REFERENCES groups(id) ON DELETE CASCADE,
	userid integer REFERENCES users(id) ON DELETE CASCADE,
	groupname varchar(255) NOT NULL,
	admin boolean NOT NULL DEFAULT false,
	UNIQUE (groupid, userid)
);
CREATE INDEX user_group_mapping_userid_idx ON user_group_mapping(userid);
CREATE INDEX user_group_mapping_groupid_idx ON user_group_mapping(groupid);
CREATE INDEX user_group_mapping_userid_groupid_idx ON user_group_mapping(userid, groupid); -- TODO check if needed

-- mapping of decks to groups
CREATE TABLE deck_group_mapping(
	deckid integer REFERENCES deck(id) ON DELETE CASCADE,
	groupid integer REFERENCES groups(id) ON DELETE CASCADE,
	deckname varchar(255) NOT NULL, -- duplicated to avoid an extra join with the deck table, with increased storage space as tradeof
	UNIQUE (deckid, groupid)
);
CREATE INDEX deck_group_mapping_deckid_idx ON deck_group_mapping(deckid);
CREATE INDEX deck_group_mapping_groupid_idx ON deck_group_mapping(groupid);
CREATE INDEX deck_group_mapping_deckid_groupid_idx ON deck_group_mapping(deckid, groupid); -- TODO check if needed

CREATE TABLE discuss(
	id BIGSERIAL PRIMARY KEY,
	deck_id integer REFERENCES deck(id) ON DELETE CASCADE,
	card_id bigint REFERENCES card(id) ON DELETE CASCADE,
	owner integer REFERENCES users(id) ON DELETE SET NULL, -- user that commented
	inreplyto bigint REFERENCES discuss(id) ON DELETE SET NULL,
	name varchar(100), -- of user that commented
	comment varchar(4096) NOT NULL,
	isauthor boolean NOT NULL DEFAULT FALSE, -- is it the course authour commenting?
	created TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX card_discuss_card_id_idx ON discuss(card_id);
CREATE INDEX card_discuss_deck_id_idx ON discuss(deck_id);

CREATE TABLE lostpw(
	id SERIAL PRIMARY KEY,
	user_id integer REFERENCES users(id) ON DELETE CASCADE,
	code varchar(20), -- code sent in URL
	created TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX lostpw_code_idx ON lostpw(code);

END; -- end transaction

 -- if dev is the db login user, set privileges:
--GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA PUBLIC TO dev;
--GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA PUBLIC TO dev;
--GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA PUBLIC TO dev;

--6.6 to 6.8:
begin;

--ALTER TABLE deck ADD COLUMN price integer NOT NULL DEFAULT 0; -- for now this is the payex price in USD, i.e. $20.00 = 2000

CREATE TABLE payex_transaction(
	id SERIAL PRIMARY KEY,
	created TIMESTAMP NOT NULL DEFAULT now(),
	
	userId integer REFERENCES users(id) ON DELETE SET NULL,
	deckId integer REFERENCES deck(id) ON DELETE SET NULL,
	price smallint,
	currency varchar(10),
	vat smallint,
	productNumber integer,
	description varchar(255),
	clientIPAddress varchar(64),
	clientIdentifier varchar(64),
	px_view varchar(20),
	agreementRef varchar(64),
	clientLanguage varchar(6), 
	px_init_id varchar(64),
	px_init_date varchar(64),
	px_init_description varchar(255),
	px_init_errorCode varchar(64),
	px_init_orderRef varchar(64),
	px_init_redirectUrl varchar(255),
	px_com_id varchar(64),
	px_com_date varchar(64),
	px_com_code varchar(64),
	px_com_description varchar(255),
	px_com_errorCode varchar(64),
	px_com_transactionStatus varchar(64),
	px_com_transactionErrorCode varchar(64),
	px_com_transactionNumber varchar(64),
	soap_init_resp varchar(4096),
	soap_complete_resp varchar(4096)
);
CREATE INDEX payex_transaction_px_init_orderRef_idx ON payex_transaction(px_init_orderRef);
CREATE INDEX payex_transaction_createdx ON payex_transaction(created);

ALTER TABLE card DROP COLUMN ordering;
ALTER TABLE card ADD COLUMN ordering integer; -- card initial ordering in deck, start from 0, add -1 or 1 if adding card to start or end of deck,
												-- on reordering, just incremaent all ordering nbrs for all cards with higher ordering then the inserted card 

-- lets keep the question, answr, hint and longanswer fields with generic html, and just not use them for new courses.
-- can be usefull later to suck in generic original html from web pages 
ALTER TABLE card ADD COLUMN q_title varchar(160); --twitter length...
ALTER TABLE card ADD COLUMN q_text varchar(4095);
ALTER TABLE card ADD COLUMN q_img varchar(255);

ALTER TABLE card ADD COLUMN a_title varchar(160);
ALTER TABLE card ADD COLUMN a_text varchar(4095);
ALTER TABLE card ADD COLUMN a_img varchar(255);
ALTER TABLE card ADD COLUMN a_title_2 varchar(160);
ALTER TABLE card ADD COLUMN a_text_2 varchar(4095);
ALTER TABLE card ADD COLUMN a_img_2 varchar(255);
ALTER TABLE card ADD COLUMN a_title_3 varchar(160);
ALTER TABLE card ADD COLUMN a_text_3 varchar(4095);
ALTER TABLE card ADD COLUMN a_img_3 varchar(255);

ALTER TABLE card ADD COLUMN la_title varchar(160);
ALTER TABLE card ADD COLUMN la_text varchar(4095);
ALTER TABLE card ADD COLUMN la_img varchar(255);
ALTER TABLE card ADD COLUMN la_title_2 varchar(160);
ALTER TABLE card ADD COLUMN la_text_2 varchar(4095);
ALTER TABLE card ADD COLUMN la_img_2 varchar(255);
ALTER TABLE card ADD COLUMN la_title_3 varchar(160);
ALTER TABLE card ADD COLUMN la_text_3 varchar(4095);
ALTER TABLE card ADD COLUMN la_img_3 varchar(255);

end;

--6.8 to 6.10:
begin;

CREATE TABLE loc(
  id serial PRIMARY KEY,
  type smallint NOT NULL DEFAULT 0,
  content text
);

INSERT into loc (content) VALUES ('');

end;

-- to 6.12:
begin;

ALTER TABLE card ALTER COLUMN la_text TYPE varchar(65535);
ALTER TABLE deck ALTER COLUMN long_description TYPE varchar(65535);

ALTER TABLE card DROP COLUMN question;
ALTER TABLE card DROP COLUMN answer;
ALTER TABLE card DROP COLUMN longanswer;

end;

--to 6.13:
begin;

--ALTER TABLE card ALTER COLUMN la_text TYPE varchar(65535);
--ALTER TABLE deck ALTER COLUMN long_description TYPE varchar(65535);
--
--ALTER TABLE card DROP COLUMN question;
--ALTER TABLE card DROP COLUMN answer;
--ALTER TABLE card DROP COLUMN longanswer;

ALTER TABLE my_courses ADD COLUMN updated bigint NOT NULL DEFAULT 0; -- unix time in seconds (not millis) when this entry was written (state is valid for a "day" only, i.e should be reset at 05.00 in the morning in users timezone.
ALTER TABLE my_courses ADD COLUMN disabled boolean NOT NULL DEFAULT FALSE; -- course is disabled from study all play list
ALTER TABLE my_courses ADD COLUMN mfc smallint; -- max failed cards before starting to repeat the failed cards only
ALTER TABLE my_courses ADD COLUMN mnc smallint; -- max new cards to be shown per day
ALTER TABLE my_courses ADD COLUMN tbm smallint; -- time box minutes
ALTER TABLE my_courses ADD COLUMN ncs smallint NOT NULL DEFAULT 0; -- new cards already shown today
ALTER TABLE my_courses ADD COLUMN name varchar(255);

CREATE INDEX my_courses_disabled_idx ON my_courses(disabled);

-- migrate data from the old table:
UPDATE my_courses AS m
SET updated = u.updated,
  disabled = (u.disabled IS NOT FALSE),
  mfc = u.mfc,
  mnc = u.mnc,
  tbm = u.tbm,
  ncs = u.new_cards_shown,
  name = u.name
FROM user_deck_state AS u
WHERE m.user_id = u.user_id AND m.deck_id = u.deck_id;

UPDATE my_courses AS m
SET name = d.name
FROM deck AS d
WHERE m.deck_id = d.id;

DROP TABLE IF EXISTS user_deck_state CASCADE;

-- remove "hidden" from deck table, and let delete btn when admin just unpublish from store:
UPDATE deck SET private=TRUE, approved=FALSE, pending_approve=FALSE where hidden IS TRUE;
ALTER TABLE deck DROP COLUMN hidden;

ALTER TABLE card_spacing DROP COLUMN hidden; -- now do JOIN with my_courses to find out if hidden

end;

--to 6.14:
begin;

--ALTER TABLE deck ADD COLUMN keywords varchar(512); -- comma separated
--ALTER TABLE deck ADD COLUMN ld_txt character varying(65535); -- this is the long description, but with text only, i.e. no html tags (for seach indexing)
--ALTER TABLE deck DROP COLUMN ld_txt;

-- all words we have indexed (stemmed)
CREATE TABLE words(
	id SERIAL PRIMARY KEY,
	word varchar(20) NOT NULL UNIQUE
);
CREATE INDEX words_word_idx ON words(word);

-- mapping table of deck to words
--DROP TABLE IF EXISTS deckwords;
CREATE TABLE deckwords(
	id SERIAL PRIMARY KEY,
	deck_id integer REFERENCES deck(id) ON DELETE CASCADE,
	word_id integer REFERENCES words(id) ON DELETE CASCADE,
	UNIQUE(deck_id, word_id)
);
CREATE INDEX deckwords_word_idx ON deckwords(word_id);

end;

-- insert into words (word) values ('car'); 
--insert into deckwords(deck_id, word_id) values (383, 1);
--insert into deckwords(deck_id, word_id) values (383, 2);
--insert into deckwords(deck_id, word_id) values (376, 1);
--insert into deckwords(deck_id, word_id) values (376, 2);
--insert into deckwords(deck_id, word_id) values (376, 3);
--insert into deckwords(deck_id, word_id) values (379, 3);
-- select distinct deck_id from deckwords where word_id in (1, 2, 3);
-- to get all courses that has any of the given words:
--select distinct deck_id from deckwords where word_id in (select id from words where word in ('car', 'cat'));
-- add course to mappng table:
--insert into deckwords (deck_id, word_id) select 374, id from words where word in ('car', 'mouse');
-- multiple words insert:
--insert into words (word) values ('asdf'), ('asdfd');
-- multiple insert of only words that are not in words table already:
--insert into words (word) (select * from (values ('cat'),('mouse'),('asdfasdfds'),('blar')) AS v except (select word from words where word in ('cat', 'mouse', 'asdfasdfds','blar')));

--to 6.15:
begin;

ALTER TABLE user_settings ADD COLUMN notif_days smallint NOT NULL DEFAULT 1; -- nbr days between notifications, 0 = off
ALTER TABLE user_settings ADD COLUMN last_notif TIMESTAMP NOT NULL DEFAULT now();

-- add all users to user_settings so we can use new mail functionality:
ALTER TABLE user_settings ALTER COLUMN max_failed SET NOT NULL;
ALTER TABLE user_settings ALTER COLUMN max_failed SET DEFAULT 10;
ALTER TABLE user_settings ALTER COLUMN max_new_day SET NOT NULL;
ALTER TABLE user_settings ALTER COLUMN max_new_day SET DEFAULT 10;
UPDATE user_settings SET timebox_min = 0;
ALTER TABLE user_settings ALTER COLUMN timebox_min SET NOT NULL;
ALTER TABLE user_settings ALTER COLUMN timebox_min SET DEFAULT 0;
insert into user_settings (user_id) (select id from users AS i except (select user_id from user_settings));

end;

--to6.16:
begin;

ALTER TABLE deck DROP CONSTRAINT deck_category_name_key; -- remove UNIQUE (category, name) since interfering with bot course creation

end;


