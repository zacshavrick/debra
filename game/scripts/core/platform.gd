extends Node
## Autoload `Platform`: what are we running on, and how much can it handle?
## Everything that scales with device power (grass density, shadows, view
## distance) reads `quality` from here instead of checking OS features itself.

enum Quality { LOW, HIGH }

## True on phones/tablets, native or in a mobile browser.
var is_mobile := false
## True when running as an HTML5 export (desktop or mobile browser).
var is_web := false
var quality: Quality = Quality.HIGH


func _ready() -> void:
	is_web = OS.has_feature("web")
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	# Fallback: the web feature tags miss some browsers (and devtools emulation).
	# A touchscreen in a browser is treated as a phone/tablet.
	if is_web and DisplayServer.is_touchscreen_available():
		is_mobile = true
	quality = Quality.LOW if is_mobile else Quality.HIGH
	# Command-line override for perf testing on desktop: `-- --quality=low`
	for arg in OS.get_cmdline_user_args():
		if arg == "--quality=low":
			quality = Quality.LOW
		elif arg == "--quality=high":
			quality = Quality.HIGH
	print("Platform: web=%s mobile=%s touchscreen=%s quality=%s" % [is_web, is_mobile,
		DisplayServer.is_touchscreen_available(), Quality.keys()[quality]])


func is_low() -> bool:
	return quality == Quality.LOW


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
