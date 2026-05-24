

migrate:
	odin run ./src/db/migrate.odin -file -- oudio.db

drop: 
	rm -rf oudio.db

sync:
	odin run ./src/library/

ui:
	odin run ./src/main.odin -file
