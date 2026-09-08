package main

import "core:log"
import "core:fmt"
import sf "libsndfile"

AudioBuffer :: struct {
	data: []f32,
	frames: u64,
	channels: u64,
	filePath: string,
	read: proc(buffer: ^AudioBuffer, frame: u64, channel: u64 = 0) -> f32,

}

AudioBuffer_read :: proc(buffer: ^AudioBuffer, frame: u64, channel: u64 = 0) -> f32 {
	index := frame * auto_cast(buffer.channels) + auto_cast(channel)
	index = clamp(index, 0, buffer.frames * buffer.channels - 1)
	return buffer.data[index]
}

AudioBuffer_create :: proc(filePath: string ) -> (buffer: ^AudioBuffer, err: string) {
	info := sf.SF_INFO{}
	sndFile := sf.sf_open(fmt.ctprint(filePath), sf.SFM_READ, &info)
	defer sf.sf_close(sndFile)
	if sndFile == nil {
		return nil, string(sf.sf_strerror(sndFile))
	}
	buffer = new(AudioBuffer)
	AudioBuffer_init(buffer)
	buffer.filePath = filePath
	buffer.channels = auto_cast info.channels
	buffer.frames = auto_cast info.frames
	buffer.data = make([]f32, info.frames * auto_cast info.channels)
	framesRead := sf.sf_readf_float(sndFile, &buffer.data[0], info.frames)
	if framesRead != info.frames {
		log.debug(framesRead, " frames read from ", buffer.filePath)
	}

	return buffer, ""
}

AudioBuffer_init :: proc(buffer: ^AudioBuffer) {
	buffer.read = AudioBuffer_read
}
