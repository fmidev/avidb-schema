# avidb-schema
Aviation message database schema

If pg_partman -partitioning is used (avidb_partman.sql, created for pg_partman 5.4.0), partman maintenance should be run at least monthly to create new partitions.

This can be done with pg_partman's included background worker (instructions in https://github.com/pgpartman/pg_partman) or with e.g. a cronjob running (as user postgres or avidb_rw): 

psql -d avidb -c 'SELECT partman.run_maintenance();' 
