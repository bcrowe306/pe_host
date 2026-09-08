package main
import ped "port_engine_device"

AudioDeviceNode :: struct {
	using node: AudioNode,
	device: ^ped.Device,
	processData: ped.Process,
	setParameterValue: proc(node: ^AudioDeviceNode, parameterId: u32, value: f64),
	deviceInputEvents: [dynamic]ped.Event,
	processFinishedCallback: proc(node: ^AudioDeviceNode, user_data: rawptr),
	callbackUserData: rawptr,
}

AudioDeviceNode_create :: proc(device: ^ped.Device) -> ^AudioDeviceNode {
	node := new(AudioDeviceNode)
	AudioNode_configure(node)
	node.process = AudioDeviceNode_process
	node.setParameterValue = AudioDeviceNode_setParameterValue
	node.device = device
	reserve(&node.deviceInputEvents, 128) // Reserve space for input events
	return node
}


AudioDeviceNode_process :: proc(node: ^AudioDeviceNode, audioContext: ^AudioContext, outputBuffer: []f32, midiBuffer: []MidiEvent) {
	node := cast(^AudioDeviceNode)node

	node.processData.audio_context.frames_per_buffer = audioContext.framesPerBuffer
	node.processData.audio_context.sample_rate = audioContext.sampleRate
	node.processData.input_buffer = outputBuffer
	node.processData.output_buffer = outputBuffer
	node.processData.audio_context.input_channels = audioContext.inputChannels
	node.processData.audio_context.output_channels = audioContext.outputChannels
	node.processData.input_events = node.deviceInputEvents[:]
	if node.device != nil {
		node.device->process(&node.processData)
	}
	clear(&node.deviceInputEvents)
	if node.processFinishedCallback != nil {
		node.processFinishedCallback(node, node.callbackUserData)
	}
}

AudioDeviceNode_setParameterValue :: proc(node: ^AudioDeviceNode, parameterId: u32, value: f64) {
	if node.device != nil {
		paramChangeEvent := ped.PARAM_CHANGE_EVENT {
			header= ped.EventHeader{
				type = .PARAM_CHANGE,
				time = 0,
				flags = {.IS_LIVE}
			},
			param_index = parameterId,
			value = value
		}
		append(&node.deviceInputEvents, paramChangeEvent)
	}
}
