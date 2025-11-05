-- Create user for B2B application
CREATE USER b2b_user IDENTIFIED BY b2b_password;
GRANT CONNECT, RESOURCE, DBA TO b2b_user;
GRANT UNLIMITED TABLESPACE TO b2b_user;

-- Connect as the new user
-- ALTER SESSION SET CURRENT_SCHEMA = b2b_user;

COMMIT;