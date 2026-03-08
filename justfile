

migrate:
	odin run ./src/db/migrate.odin -file

drop: 
	rm -rf ./oudio.db
