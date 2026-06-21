

migrate:
	odin run ./src/db/migrate.odin -file -- oudio.db

drop: 
	rm -rf oudio.db

sync:
	odin run ./src/library/

ui:
	odin build ./src/main.odin -file -o:none -debug -out:./build/ui && ./build/ui

playback:
	odin build ./src/main.odin -file -o:none -debug -out:./build/playback && ./build/playback
