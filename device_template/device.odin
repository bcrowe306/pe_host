package device_template

import "core:fmt"
import "core:math"
import pe "../port_engine_device"

Template_Device_State :: struct {
	sample_rate: f64,
}

SineWaveState :: struct {
	phase: f64,
}

template_create_device :: proc( factory: ^pe.DeviceFactory, index: u32 ) -> ^pe.Device {
	if index != 0 {
		return nil
	}

	device := new(pe.Device)
	device.device_data = new(SineWaveState)
	device.desc = &template_descriptor
	device.device_data = new(Template_Device_State)
	device.fields = make(map[string]pe.DeviceField)
	pe.Device_configure(device)

	device.init             = template_init
	device.destroy          = template_destroy
	device.activate         = template_activate
	device.deactivate       = template_deactivate
	device.start_processing = template_start_processing
	device.stop_processing  = template_stop_processing
	device.reset            = template_reset
	device.process          = pe.Device_process
	device.handle_input_events = template_handle_input_events
	device.process_audio    = template_process_audio

	template_create_parameters(device)
	template_create_fields(device)

	return device
}

template_init :: proc(device: ^pe.Device) -> bool {
	return true
}

template_destroy :: proc(device: ^pe.Device) {
	free(cast(^Template_Device_State)device.device_data)
	delete(device.parameters)
	delete(device.fields)
}

template_activate :: proc(
	device: ^pe.Device,
	sample_rate: f64,
	min_frames, max_frames: u32,
) -> bool {
	state := cast(^Template_Device_State)device.device_data
	state.sample_rate = sample_rate
	return true
}

template_deactivate :: proc(device: ^pe.Device) {}

template_start_processing :: proc(device: ^pe.Device) -> bool {
	return true
}

template_stop_processing :: proc(device: ^pe.Device) {}

template_reset :: proc(device: ^pe.Device) {}

template_handle_input_events :: proc(
	device: ^pe.Device,
	event: pe.Event,
	output_events: ^[dynamic]pe.Event,
) {
	// Handle MIDI, note, and timing events here.
}

template_process_audio :: proc(
	device: ^pe.Device,
	process: ^pe.Process,
) -> pe.Process_Status {
	gain := f32(device->get_param_info(0)->evaluate())
	frequency := f64(device->get_param_info(1)->evaluate())
	sample_count := min(len(process.input_buffer), len(process.output_buffer))

	output := process.output_buffer
	input := process.input_buffer
	sineState := cast(^SineWaveState)device.device_data
	for frame in 0..<process.audio_context.frames_per_buffer {
		// Calculate sine wave sample for this frame
		sineState.phase += 2.0 * math.PI * frequency / process.audio_context.sample_rate
		if sineState.phase > 2.0 * math.PI {
			sineState.phase -= 2.0 * math.PI
		}
		samp := math.sin(sineState.phase) * auto_cast gain
		for channel in 0..<process.audio_context.output_channels {
			sample_index := frame * process.audio_context.output_channels + channel
			output[sample_index] = f32(samp)
		}
	}

	return .CONTINUE
}
