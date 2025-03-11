/* Start session mySession */ 
cas mySession;

proc cas;
table.tableExists result=r /
	caslib = 'casuser',
	name = 'price_data'
;

if r.exists==0 then do;
	table.loadTable / caslib="casuser"
		path="PRICE_DATA_RAW.sashdat"
		casOut={
			caslib="casuser",
			name="price_data",
			promote=TRUE
		};
end;
run;

table.dropTable /
	caslib = "casuser",
	name = "filtered_price_data",
	quiet = TRUE
;
run;

* Show the host names used by the server;
builtins.listNodes result=res;
put res;
run;

loadactionset 'gateway';

* By default, read_table returns the table as a data.frame;
externalsource rprog;
print(paste('Total number of workers:', gw$num_workers))
print(paste('Total number of threads:', gw$num_threads))

# Read the CAS table
tbl <- gateway::read_table(list(name = 'price_data', caslib = 'casuser'))

# Compute dimension per thread
info <- dim(tbl)
print(paste('Thread', gw$thread_id, ':', 
		'Number of rows:', info[1] , 
		'Number of columns:', info[2]))

# Check the column types
column_type <- class(tbl$price_date)
print(paste('Thread', gw$thread_id, ':',
		'price_date column type:', column_type))

# Ensure `price_date` is recognized as a Date type
if (!inherits(tbl$price_date, "Date")) {
  tbl$price_date <- as.Date(tbl$price_date)  # Convert if needed
}

print(paste("Is date?", inherits(tbl$price_date, "Date")))

# Compute minimum and maximum dates per thread
local_min_date <- min(tbl$price_date, na.rm = TRUE)
local_max_date <- max(tbl$price_date, na.rm = TRUE)
print(paste('Thread', gw$thread_id, 'Min Date:', local_min_date))
print(paste('Thread', gw$thread_id, 'Max Date:', local_max_date))

# Define filter condition
filter_date <- as.Date("2015-06-01")
filtered_tbl <- tbl[tbl$price_date > filter_date, ]

# Compute dimension per thread after filtering
info <- dim(filtered_tbl)
print(paste('Thread', gw$thread_id, ':', 
		'Number of rows:', info[1] , 
		'Number of columns:', info[2]))

# Compute the minimum date per thread
local_min_date <- min(filtered_tbl$price_date, na.rm = TRUE)
local_max_date <- max(filtered_tbl$price_date, na.rm = TRUE)
print(paste('Thread', gw$thread_id, 'Min Date:', local_min_date))
print(paste('Thread', gw$thread_id, 'Max Date:', local_max_date))

# Save the filtered table to CAS
gateway::write_table(filtered_tbl, list(name = 'filtered_price_data',
										caslib = 'casuser',
										promote = TRUE))
endexternalsource;

action gateway.runLang / lang= "r"
	code= rprog
	nthreads = 3;
run;

table.fetch /
	table = {
		caslib = 'casuser',
		name = 'filtered_price_data'
	},
	sortBy={{
		name='price_date'
	}};
run;
quit;

cas mySession terminate;