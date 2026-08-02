

migrate:
	odin run ./cmd/migrate/main.odin -file -out:./build/migrate -- oudio.db

drop: 
	rm -rf oudio.db

sync:
	odin run ./cmd/sync/main.odin -file -out:./build/sync

ui:
	odin run ./src/main.odin -file -o:none -debug -out:./build/ui

playback:
	odin build ./src/main.odin -file -o:none -debug -out:./build/playback && ./build/playback
