class_name ItemsData
extends RefCounted

## Katalog dan Registri Sentral Data Item untuk Buku Resep 2045
## Mengikuti spesifikasi resmi docs/CONTENT.md § 2, PRD FR05, dan penanganan alias transparan

const ItemDataClass = preload("res://scripts/inventory/item_data.gd")

var _items: Dictionary = {} # String -> Resource
var _aliases: Dictionary = {} # String -> String (alias_id -> canonical_id)

func _init() -> void:
	_register_default_p0_items()

func register_item(item: Resource) -> void:
	if item == null or str(item.get("id")).is_empty():
		push_error("ItemsData: Mencoba mendaftarkan item null atau ID kosong.")
		return
	_items[str(item.get("id"))] = item

func register_alias(alias_id: String, canonical_id: String) -> void:
	_aliases[alias_id] = canonical_id

func get_item(item_id: String) -> Resource:
	var target_id := resolve_id(item_id)
	if _items.has(target_id):
		return _items[target_id]
	return null

func get_item_name(item_id: String) -> String:
	var item := get_item(item_id)
	if item != null:
		if "display_name" in item and not str(item.get("display_name")).is_empty():
			return str(item.get("display_name"))
		elif "name" in item and not str(item.get("name")).is_empty():
			return str(item.get("name"))
	return item_id

func has_item(item_id: String) -> bool:
	var target_id := resolve_id(item_id)
	return _items.has(target_id)

func resolve_id(item_id: String) -> String:
	if _aliases.has(item_id):
		return _aliases[item_id]
	return item_id

func get_all_items() -> Array[Resource]:
	var result: Array[Resource] = []
	for k in _items:
		result.append(_items[k])
	return result

func _register_default_p0_items() -> void:
	# 1. Benih Bayam (seed_bayam)
	register_item(ItemDataClass.new(
		"seed_bayam",
		"Benih Bayam",
		"benih",
		20,
		"Benih bayam unggul pekarangan untuk ditanam di titik petak tanah.",
		null,
		Color(0.4, 0.8, 0.3)
	))
	register_alias("seed_spinach", "seed_bayam")

	# 2. Pembenah Tanah (soil_compost)
	register_item(ItemDataClass.new(
		"soil_compost",
		"Pembenah Tanah",
		"alat_bahan",
		20,
		"Bahan organik pembenah struktur tanah untuk persiapan petak gembur.",
		null,
		Color(0.35, 0.25, 0.15)
	))

	# 3. Pupuk Dasar / Organik (fertilizer_basic) - Alias: tool_fertilizer
	register_item(ItemDataClass.new(
		"fertilizer_basic",
		"Pupuk Dasar",
		"alat_bahan",
		20,
		"Nutrisi tanah organik untuk mengembalikan kesuburan petak tanaman saat nutrisi < 20.",
		null,
		Color(0.5, 0.35, 0.2)
	))
	register_alias("tool_fertilizer", "fertilizer_basic")

	# 4. Sayur Bayam (ingredient_bayam) - Alias: crop_bayam
	register_item(ItemDataClass.new(
		"ingredient_bayam",
		"Sayur Bayam",
		"bahan",
		20,
		"Daun bayam hijau segar hasil panen pekarangan, bahan utama sayur bening.",
		null,
		Color(0.2, 0.7, 0.2)
	))
	register_alias("crop_bayam", "ingredient_bayam")
	register_alias("crop_spinach", "ingredient_bayam")

	# 5. Jagung Manis (ingredient_jagung)
	register_item(ItemDataClass.new(
		"ingredient_jagung",
		"Jagung Manis",
		"bahan",
		20,
		"Tongkol jagung manis sisa kebun keluarga di ujung jalan desa.",
		null,
		Color(0.95, 0.8, 0.2)
	))

	# 6. Temu Kunci (ingredient_temu_kunci)
	register_item(ItemDataClass.new(
		"ingredient_temu_kunci",
		"Temu Kunci",
		"bahan",
		20,
		"Rimpang temu kunci beraroma segar dari tepi rumpun bambu.",
		null,
		Color(0.8, 0.5, 0.25)
	))

	# 7. Sayur Bening Bayam dan Jagung (dish_sayur_bening)
	register_item(ItemDataClass.new(
		"dish_sayur_bening",
		"Sayur Bening Bayam dan Jagung",
		"masakan",
		20,
		"Hidangan kuah bening hangat tradisional dengan bayam, jagung manis, dan aroma temu kunci.",
		null,
		Color(0.85, 0.45, 0.25)
	))

	# 8. Air Bersih (water_fresh)
	register_item(ItemDataClass.new(
		"water_fresh",
		"Air Bersih",
		"bahan",
		20,
		"Air sumur segar jernih untuk kebun dan keperluan dapur.",
		null,
		Color(0.3, 0.6, 0.9)
	))
