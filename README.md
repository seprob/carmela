# Carmela

## Synopsis

Carmela is a tool used for restoring Cassandra database backups on Ubuntu systems.

There are two seperate instances of Carmela:
- "carmela1.sh": used to restore just one or a few different tables or keyspaces from backup,
- "carmela2.sh": used to restore all keyspaces from a given snapshot.

## Usage

"**carmela1.sh**":
```
carmela1.sh -k keyspace_name -t table_name -d path_to_backup -b database_home_directory
```
where
- "keyspace_name" is a keyspace name to restore,
- "table_name" is a table name to restore,
- "path_to_backup" is a path to backup files,
- "database_home_directory" is a full path to the directory with Cassandra database files.

Optional usage is 
```
carmela1.sh -h
``` 
which lets you print information about the tool's usage.

"**carmela2.sh**"
```
carmela2.sh -d database_home_directory -s snapshot_number
```
where
- "database_home_directory" is a full path to the directory with Cassandra database files,
- "snapshot_number" is a snapshot number printed after using nodetool software.

Optional usage is 
```
carmela12.sh -h
``` 
which lets you print information about the tool's usage.