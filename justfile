

migrate:
	odin run ./src/db/migrate.odin -file -- oudio.db

drop: 
	rm -rf oudio.db
