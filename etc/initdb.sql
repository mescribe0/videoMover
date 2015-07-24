-- active foreign_keys
PRAGMA foreign_keys = ON;

-- init
-- drop table video;

-- table video
-- ALTER TABLE video ADD COLUMN movieRenamer INTEGER  DEFAULT 0
create table video  ( 
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  ctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  tname TEXT,
  fname TEXT,
  fnameOut TEXT NOT NULL,
  movieRenamer INTEGER DEFAULT 0
);

--------------------------------------------------------------------------------
-- ALTER TABLE video RENAME TO tmp_video;
--------------------------------------------------------------------------------
-- create table video  ( 
-- 	 id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
-- 	 ctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
-- 	 tname TEXT,
-- 	 fname TEXT NOT NULL,
--   movieRenamer INTEGER DEFAULT 0
-- );
-- 
-- INSERT INTO video(id, ctime, tname, fname, movieRenamer)
-- SELECT id, ctime, tname, fname, movieRenamer
-- FROM tmp_video;
-- 
--------------------------------------------------------------------------------
-- create table video  ( 
--   id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
--   ctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
--   tname TEXT,
--   fname TEXT,
--   fnameOut TEXT NOT NULL,
--   movieRenamer INTEGER DEFAULT 0
-- );

-- INSERT INTO video(id, ctime, tname, fname, movieRenamer, fnameOut) 
-- SELECT id, ctime, tname, fname, movieRenamer, "x" FROM tmp_video;
--------------------------------------------------------------------------------
-- DROP TABLE tmp_video;
--------------------------------------------------------------------------------