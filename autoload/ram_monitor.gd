extends Node

signal updated

var total_mb: int = 0
var available_mb: int = 0
var swap_total_mb: int = 0
var swap_free_mb: int = 0
var pressure: float = 0.0
var _timer: Timer
var _size_cache: Dictionary = {}

func _ready() -> void:
	refresh()
	_timer = Timer.new()
	_timer.wait_time = 2.0
	_timer.autostart = true
	_timer.timeout.connect(refresh)
	add_child(_timer)

func refresh() -> void:
	var info := _read_meminfo()
	if info.is_empty():
		return
	total_mb = int(info.get("MemTotal", 0)) / 1024
	available_mb = int(info.get("MemAvailable", 0)) / 1024
	if available_mb <= 0:
		available_mb = (int(info.get("MemFree", 0)) + int(info.get("Buffers", 0)) + int(info.get("Cached", 0))) / 1024
	swap_total_mb = int(info.get("SwapTotal", 0)) / 1024
	swap_free_mb = int(info.get("SwapFree", 0)) / 1024
	if total_mb > 0:
		pressure = clampf(float(total_mb - available_mb) / float(total_mb), 0.0, 1.0)
	updated.emit()

func _read_meminfo() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open("/proc/meminfo", FileAccess.READ)
	if f == null:
		return out
	var lines := f.get_as_text().split("\n")
	f.close()
	for line in lines:
		var pos := line.find(":")
		if pos <= 0:
			continue
		var key := line.substr(0, pos).strip_edges()
		var rest := line.substr(pos + 1).strip_edges().split(" ")
		if rest.size() > 0 and rest[0].is_valid_int():
			out[key] = int(rest[0])
	return out

func model_size_mb(path: String) -> int:
	if path == "":
		return 0
	if _size_cache.has(path):
		return int(_size_cache[path])
	var bytes := 0
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			bytes = f.get_length()
			f.close()
	var mb := int(bytes / 1048576)
	_size_cache[path] = mb
	return mb

func kv_per_token_kb(model_path: String) -> int:
	var p := model_path.to_lower()
	if p.contains("1.5b") or p.contains("1_5b"):
		return 18
	if p.contains("3b"):
		return 36
	if p.contains("7b"):
		return 56
	if p.contains("9b"):
		return 70
	return 40

func estimate_footprint_mb(model_path: String, n_ctx: int) -> int:
	var size := model_size_mb(model_path)
	if size <= 0:
		size = 2000
	var kv := int(float(kv_per_token_kb(model_path) * n_ctx) / 1024.0)
	return size + kv + 340

func total_used_mb() -> int:
	return total_mb - available_mb

func format_gb(mb: int) -> String:
	return "%.1f ГБ" % (float(mb) / 1024.0)

func format_mb(mb: int) -> String:
	if mb >= 1024:
		return format_gb(mb)
	return "%d МБ" % mb

func describe_pressure() -> String:
	if pressure < 0.72:
		return "Свободно"
	if pressure < 0.86:
		return "Напряжение"
	return "Мало памяти"

func is_risky(footprint_mb: int) -> bool:
	return available_mb > 0 and available_mb < footprint_mb + 180

func suggestion(model_path: String, n_ctx: int) -> String:
	if total_mb <= 0:
		return ""
	var footprint := estimate_footprint_mb(model_path, n_ctx)
	if is_risky(footprint):
		return "Свободно %s, а модели нужно около %s. Включите лёгкий режим или уменьшите контекст до 2048–4096." % [format_gb(available_mb), format_mb(footprint)]
	return "Расчётный рабочий набор: около %s. Свободно %s." % [format_mb(footprint), format_gb(available_mb)]
