package db

import "core:crypto"
import "core:encoding/uuid"
import "core:strings"


db_url: cstring = "oudio.db"

gen_id :: proc(prefix: Maybe(string), allocator := context.allocator) -> string {
	id: string

	context.random_generator = crypto.random_generator()

	id_uuid := uuid.generate_v7_basic()

	uuid_str := uuid.to_string(id_uuid, allocator)
	defer delete(uuid_str)

	if (prefix != nil) {
		id = strings.concatenate([]string{prefix.?, "_", uuid_str})
	} else {
		id = uuid_str
	}

	return id
}
