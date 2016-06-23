# Hospital transfers

The code identifies basic nested, overlapping and serial transfers. Two versions are provided:
- transfers.sas makes use of upside-down data to populate the final episode_end_date to all records;
- transfers_sql.sas makes use of PROC SQL to populate the final episode_end_date to all records.
