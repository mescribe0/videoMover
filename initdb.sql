-- active foreign_keys
PRAGMA foreign_keys = ON;

-- init
-- drop table video;

-- table video
create table video  ( 
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	ctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
	tname TEXT NOT NULL,
	fname TEXT NOT NULL
);
