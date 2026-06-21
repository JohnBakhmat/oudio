package playback

import "core:fmt"
import "core:log"
import "core:time"

import core "../core"
import ma "vendor:miniaudio"


data_callback :: proc "c" (
	device: ^ma.device,
	output: rawptr,
	input: rawptr,
	frame_count: u32,
) {

	decoder := cast(^ma.decoder)device.pUserData
	if decoder == nil { return }

	frames_read: u64
	ma.decoder_read_pcm_frames(
		decoder,
		output,
		cast(u64)frame_count,
		&frames_read,
	)
	if frames_read == 0 {
		ma.device_stop(device)
	}

}

basic_playback :: proc() {
	fmt.printfln("Basic playback start")
	file_path: cstring = "/mnt/secondary/music/As Tall as Lions - You Can\'t Take It With You (2009)/01. As Tall as Lions - Circles.flac"
	fmt.printfln("Playing %s", file_path)

	decoder: ma.decoder

	device: ma.device
	result := ma.decoder_init_file(file_path, nil, &decoder)

	fmt.printfln(fmt.aprintf("decoder_init_file result %v", result))
	// assert ok

	device_config := ma.device_config_init(ma.device_type.playback)
	device_config.playback.format = decoder.outputFormat
	device_config.playback.channels = decoder.outputChannels
	device_config.sampleRate = decoder.outputSampleRate
	device_config.pUserData = &decoder
	device_config.dataCallback = data_callback


	if res := ma.device_init(nil, &device_config, &device); res != .SUCCESS {
		core.log_error("Failed to open playback device.")
		ma.decoder_uninit(&decoder)
		return
	}

	if res := ma.device_start(&device); res != .SUCCESS {
		core.log_error("Failed to start playback device.")
		ma.device_uninit(&device)
		ma.decoder_uninit(&decoder)
		return
	}

	for ma.device_is_started(&device) {
		time.sleep(100 * time.Millisecond)
	}

	ma.device_uninit(&device)
	ma.decoder_uninit(&decoder)
}
