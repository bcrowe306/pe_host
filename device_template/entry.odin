package device_template

import pe "../port_engine_device"

template_entry_init :: proc(device_path: string) -> bool {
	return true
}

template_entry_get_factory :: proc() -> ^pe.DeviceFactory {
	return &template_factory
}

// The host discovers this exported value when it loads the shared library.
@export
device_entry : pe.Entry = {
	pe_device_version = pe.Version{major = 1, minor = 0, patch = 1},
	init              = template_entry_init,
	get_factory       = template_entry_get_factory,
}
