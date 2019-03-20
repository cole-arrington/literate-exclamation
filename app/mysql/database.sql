CREATE DATABASE IF NOT EXISTS rescale_hw; 
USE rescale_hw;

CREATE TABLE hardware (
  id integer primary key auto_increment,
  provider text not null,
  name text not null);

INSERT INTO hardware(provider, name) VALUES ('Amazon', 'c5');
INSERT INTO hardware(provider, name) VALUES ('Azure', 'H16mr');
