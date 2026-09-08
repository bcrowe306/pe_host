package device_template

import pe "../port_engine_device"

template_descriptor := pe.Device_Descriptor{
	pe_device_version = pe.PEVersion,
	id                = "com.example.template-gain",
	name              = "Template Gain",
	vendor            = "Example",
	url               = "https://example.com",
	manual_url        = "https://example.com/template-gain/manual",
	support_url       = "https://example.com/support",
	verison           = "1.0.0",
	description       = "A gain effect demonstrating the Port Engine Device SDK.",
	type              = .AudioEffect,
	category          = {.Utility},
}
