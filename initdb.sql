-- active foreign_keys
PRAGMA foreign_keys = ON;

-- init
-- drop table video;

-- table video
-- ALTER TABLE video ADD COLUMN movieRenamer INTEGER  DEFAULT 0
create table video  ( 
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	ctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
	tname TEXT NOT NULL,
	fname TEXT NOT NULL,
  movieRenamer INTEGER DEFAULT 0
);
