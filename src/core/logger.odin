package core

import "core:fmt"
import "core:os"

Log_Level :: enum {
	INFO,
	DEBUG,
	ERROR,
}

Logger :: struct {
	debug_enabled: bool,
	initialized:   bool,
}

logger := Logger{}

ANSI_RESET   :: "\x1b[0m"
ANSI_RED     :: "\x1b[31m"
ANSI_DIM     :: "\x1b[2m"
ANSI_CYAN    :: "\x1b[36m"
ANSI_GREEN   :: "\x1b[32m"
ANSI_YELLOW  :: "\x1b[33m"
ANSI_MAGENTA :: "\x1b[35m"

is_truthy :: proc(value: string) -> bool {
	return value == "1" || value == "true" || value == "TRUE" || value == "yes" || value == "YES" || value == "on" || value == "ON"
}

is_debug_env :: proc() -> bool {
	debug_value := os.get_env("DEBUG", context.temp_allocator)
	defer delete(debug_value)

	app_env := os.get_env("APP_ENV", context.temp_allocator)
	defer delete(app_env)

	return is_truthy(debug_value) || app_env == "debug" || app_env == "DEBUG"
}

set_debug_enabled :: proc(enabled: bool) {
	logger.debug_enabled = enabled
	logger.initialized = true
}

init_logger :: proc() {
	logger.debug_enabled = is_debug_env()
	logger.initialized = true
}

ensure_logger :: proc() {
	if !logger.initialized {
		init_logger()
	}
}

colorize :: proc(s, color: string) -> string {
	return fmt.tprintf("%s%s%s", color, s, ANSI_RESET)
}

logf :: proc(level: Log_Level, format: string, args: ..any) {
	log(level, fmt.tprintf(format, ..args))
}

log :: proc(level: Log_Level, message: string) {
	ensure_logger()

	switch level {
	case .INFO:
		fmt.printfln("[INFO] %s", message)
	case .DEBUG:
		if logger.debug_enabled {
			fmt.printfln("[DEBUG] %s", message)
		}
	case .ERROR:
		fmt.printfln("%s[ERROR] %s%s", ANSI_RED, message, ANSI_RESET)
	}
}

log_info :: proc(message: string) {
	log(.INFO, message)
}

log_debug :: proc(message: string) {
	log(.DEBUG, message)
}

log_error :: proc(message: string) {
	log(.ERROR, message)
}

log_infof :: proc(format: string, args: ..any) {
	logf(.INFO, format, ..args)
}

log_debugf :: proc(format: string, args: ..any) {
	logf(.DEBUG, format, ..args)
}

log_errorf :: proc(format: string, args: ..any) {
	logf(.ERROR, format, ..args)
}
