package main

import "core:encoding/endian"
import "core:fmt"
import "core:log"
import "core:math"

AudioSampler :: struct {
	using node:         AudioNode,
	cursor:             f64,
	rate:               f64,
	baseNote:           int,
	buffer:             ^AudioBuffer,
	start:              u64,
	end:                u64,
	loop:               bool,
	advance:            proc(buffer: ^AudioSampler),
	read:               proc(buffer: ^AudioSampler, channel: u64 = 0) -> f32,
	readFrom:           proc(buffer: ^AudioSampler, frame: u64, channel: u64 = 0) -> f32,
	setRateByFrequency: proc(buffer: ^AudioSampler, frequency: f64),
	setRate:            proc(buffer: ^AudioSampler, rate: f64),
	setStart:           proc(buffer: ^AudioSampler, start: u64),
	setEnd:             proc(buffer: ^AudioSampler, end: u64),
}

// Reads a sample from the buffer at the current cursor position.
AudioSampler_read :: proc(audioSampler: ^AudioSampler, channel: u64 = 0) -> f32 {
	// linear interpolate cursor from f64, one sample above and one below
	buffer := audioSampler.buffer
	cursorBottom := int(audioSampler.cursor)
	cursorTop := (cursorBottom + 1) % auto_cast (buffer.frames) // wrap around to beginning if at end
	sample1 := buffer.data[cursorBottom * auto_cast (buffer.channels) + auto_cast (channel)]
	sample2 := buffer.data[cursorTop * auto_cast (buffer.channels) + auto_cast (channel)]
	interp := sample1 + (sample2 - sample1) * f32(audioSampler.cursor - auto_cast (cursorBottom))
	return interp
}

// Advances the cursor to the next sample.
AudioSampler_advance :: proc(audioSampler: ^AudioSampler) {
	audioSampler.cursor += audioSampler.rate
	if audioSampler.cursor >= auto_cast (audioSampler.end) {
		if audioSampler.loop {
			audioSampler.cursor = auto_cast (audioSampler.start)
		} else {
			audioSampler.cursor = auto_cast (audioSampler.end) - 1
		}
	}
}

AudioSampler_setRateByFrequency :: proc(audioSampler: ^AudioSampler, frequency: f64) {
	// calculate play rate from given frequency assuming base freq is midiNote 60 or middle C
	baseFreq := 440.0 * math.pow(2.0, f32(audioSampler.baseNote - 69) / 12.0)
	audioSampler.rate = frequency / auto_cast baseFreq
}

AudioSampler_setRate :: proc(audioSampler: ^AudioSampler, rate: f64) {
	audioSampler.rate = rate
}

AudioSampler_setStart :: proc(audioSampler: ^AudioSampler, start: u64) {
	audioSampler.start = clamp(start, 0, audioSampler.end)
}

AudioSampler_setEnd :: proc(audioSampler: ^AudioSampler, end: u64) {
	audioSampler.end = clamp(end, audioSampler.start, audioSampler.buffer.frames)
}


AudioSampler_init :: proc(audioSampler: ^AudioSampler, buffer: ^AudioBuffer) {
	audioSampler.cursor = 0
	audioSampler.rate = 1
	audioSampler.baseNote = 60
	audioSampler.buffer = buffer
	audioSampler.advance = AudioSampler_advance
	audioSampler.read = AudioSampler_read
	audioSampler.setRateByFrequency = AudioSampler_setRateByFrequency
	audioSampler.setRate = AudioSampler_setRate
	audioSampler.process = AudioSampler_process
	audioSampler.setStart = AudioSampler_setStart
	audioSampler.setEnd = AudioSampler_setEnd
	audioSampler.start = 0
	if buffer != nil {
		audioSampler.end = buffer.frames
		audioSampler.loop = true
	}
}

AudioSample_create :: proc(buffer: ^AudioBuffer) -> ^AudioSampler {
	audioSampler := new(AudioSampler)
	AudioSampler_init(audioSampler, buffer)
	return audioSampler
}

AudioSampler_process :: proc(
	node: ^AudioNode,
	audioContext: ^AudioContext,
	outputBuffer: []f32,
	midiBuffer: []MidiEvent,
) {
	sampler := cast(^AudioSampler)node
	for frame in 0 ..< audioContext.framesPerBuffer {
		for channel in 0 ..< audioContext.outputChannels {
			outputBuffer[frame * audioContext.outputChannels + channel] = sampler->read(
				auto_cast channel,
			)
		}
		sampler->advance()
	}
}
