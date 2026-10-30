class_name RecipesData
extends RefCounted

## Katalog Resep dan Catatan Bawaan untuk Buku Resep 2045
## Mengikuti spesifikasi resmi docs/CONTENT.md § 4, § 5, dan § 10

const RecipeDataClass = preload("res://scripts/recipe/recipe_data.gd")

const ID_RECIPE_SAYUR_BENING: String = "recipe_sayur_bening_01"
const ID_NOTE_SAYUR_BENING: String = "recipe_note_sayur_bening"
const ID_NOTE_GARDEN: String = "note_garden_01"
const ID_SIGN_FOOD: String = "sign_food_01"

static func create_sayur_bening_recipe() -> Resource:
	return RecipeDataClass.new(
		ID_RECIPE_SAYUR_BENING,
		"Sayur Bening Bayam dan Jagung",
		"station_kitchen_home",
		{
			"ingredient_bayam": 3,
			"ingredient_jagung": 1,
			"ingredient_temu_kunci": 1
		},
		{
			"ingredient_bayam": "Benih ada di wadah dekat alat. Siapkan petak di pekarangan, lalu tanam.",
			"ingredient_jagung": "Cari sisa kebun keluarga di ujung jalan, dekat pagar miring.",
			"ingredient_temu_kunci": "Periksa tanaman di tepi rumpun bambu, dekat batu besar."
		},
		"Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar.",
		ID_NOTE_SAYUR_BENING,
		"dish_sayur_bening",
		1
	)

static func get_default_notes() -> Array[Dictionary]:
	return [
		{
			"id": ID_NOTE_SAYUR_BENING,
			"title": "Catatan Resep Keluarga",
			"text": "Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar.",
			"is_unlocked": true,
			"default_unlocked": true
		},
		{
			"id": ID_NOTE_GARDEN,
			"title": "Catatan Kebun Ujung Jalan",
			"text": "Pagar boleh miring. Jangan sampai lupa jalan pulang.",
			"is_unlocked": false,
			"default_unlocked": false
		},
		{
			"id": ID_SIGN_FOOD,
			"title": "Papan Program Pangan",
			"text": "Kawasan Pangan Masa Depan — Tahap Pemeliharaan",
			"is_unlocked": false,
			"default_unlocked": false
		}
	]
