package device_template

import pe "../port_engine_device"

template_create_parameters :: proc(device: ^pe.Device) {
	gain := device->create_param()
	gain.flags = {.AUTOMATABLE}
	gain.name = "Gain"
	gain.module = "Main"
	gain.default = 1.0
	gain.min = 0.0
	gain.max = 2.0
	gain.step = 0.1
	gain.step_fine = 0.01
	gain.value = gain.default

	frequency := device->create_param()
	frequency.flags = {.AUTOMATABLE}
	frequency.name = "frequency"
	frequency.module = "Main"
	frequency.default = 440.0
	frequency.min = 55.0
	frequency.max = 2000.0
	frequency.step = 1
	frequency.step_fine = 0.1
	frequency.value = frequency.default

	mute := device->create_param()
	mute.flags = {.AUTOMATABLE, .BOOLEAN}
	mute.name = "Mute"
	mute.module = "Main"
	mute.default = 0.0
	mute.min = 0.0
	mute.max = 1.0
	mute.step = 1
	mute.step_fine = 0.1
	mute.value = mute.default

}
