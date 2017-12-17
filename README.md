# Carmela

## Synopsis

Carmela is a tool used for restoring Cassandra database backups on Ubuntu systems.

There are two seperate instances of Carmela:
- "carmela1.sh": using to restore just one or a few different tables or keyspaces from backup,
- "carmela2.sh": using to restore all keyspaces (except system keyspaces) from a given snapshot,
- "carmela3.sh": using to archive snapshot,
- "carmela4.sh": restoring all keyspaces (except system keyspaces) from given directory.

## Usage

"**carmela1.sh**":
```
carmela1.sh -k keyspace_name -t table_name -d path_to_backup -b path_to_keyspaces -c commitlog_directory
```
where
- "keyspace_name" is a keyspace name to restore,
- "table_name" is a table name to restore,
- "path_to_backup" is a path to backup files,
- "path_to_keyspaces" is a full path to the directory with Cassandra database files,
- "commitlog_directory" is a path to the directory where commitlogs are stored.

Optional usage is 
```
carmela1.sh -h
``` 
which lets you print information about the tool's usage.

"**carmela2.sh**"
```
carmela2.sh -d path_to_keyspaces -s snapshot_number
```
where
- "path_to_keyspaces" is a full path to the directory with Cassandra database files,
- "snapshot_number" is a snapshot number printed after using nodetool software.

Optional usage is 
```
carmela2.sh -h
``` 
which lets you print information about the tool's usage.

"**carmela3.sh**"
```
carmela2.sh -d keyspace_directory -f archive_name
```
where
- "keyspace_directory" is a full path to the directory with Cassandra keyspaces,
- "archive_name" is a archive name (without extension).

Optional usage is
```
carmela3.sh -h
```
which lets you print information about the tool's usage.

"**carmela4.sh**"
```
carmela4.sh -d path_to_keyspaces -b path_to_backup -c commitlog_directory
```
where
- "keyspace_directory" is a full path to the directory with Cassandra keyspaces,
- "path_to_backup" is a path to backup files,
- "commitlog_directory" is a path to the directory where commitlogs are stored.

Optional usage is
```
carmela4.sh -h
```
which lets you print information about the tool's usage.