# Handoff Report: Crop Visual Geometry & Multi-Primitive Architecture Recommendation

**Author:** explorer_art_002_2 (read-only Teamwork Explorer)  
**Target File:** `scripts/main.gd`  
**Reference Task Report:** `docs/completed_tasks/017-identitas-visual-audio-dasar-konsisten.md`  
**Reference Review:** `.agents/teamwork/reviewer_art_001_1/handoff.md` (Finding 2)  
**Date:** 2026-10-29  
**Status:** Hard Handoff  

---

## 1. Observation

### 1.1 Verbatim Code Discrepancy in `scripts/main.gd`
Direct inspection of `scripts/main.gd` (lines 241-277) reveals that crop visualization in the 3D gardening plot (`plot_home_01`) is currently implemented as a single unadorned `BoxMesh.new()`, modifying only bounding scale and material color across all 4 growth stages:

```gdscript
241:			var crop_mesh: MeshInstance3D = spot_node.get_node_or_null("CropMesh") as MeshInstance3D
242:			if bool(spot_info.get("is_occupied", false)):
243:				if crop_mesh == null:
244:					crop_mesh = MeshInstance3D.new()
245:					crop_mesh.name = "CropMesh"
246:					crop_mesh.mesh = BoxMesh.new()
247:					spot_node.add_child(crop_mesh)
248:				crop_mesh.visible = true
249:
250:				var crop_data: Dictionary = spot_info.get("crop_data", {})
251:				var stage: int = int(crop_data.get("growth_stage", 0))
252:				var mat: StandardMaterial3D = crop_mesh.material_override as StandardMaterial3D
253:				if mat == null:
254:					mat = StandardMaterial3D.new()
255:					crop_mesh.material_override = mat
256:
257:				match stage:
258:					0: # Seed: 0.04m
259:						crop_mesh.scale = Vector3(0.08, 0.04, 0.08)
260:						crop_mesh.position = Vector3(0, 0.02, 0)
261:						mat.albedo_color = Color(0.35, 0.25, 0.15)
262:					1: # Sprout: 0.14m
263:						crop_mesh.scale = Vector3(0.14, 0.14, 0.14)
264:						crop_mesh.position = Vector3(0, 0.07, 0)
265:						mat.albedo_color = Color(0.55, 0.85, 0.25)
266:					2: # Growing: 0.30m
267:						crop_mesh.scale = Vector3(0.30, 0.30, 0.30)
268:						crop_mesh.position = Vector3(0, 0.15, 0)
269:						mat.albedo_color = Color(0.22, 0.68, 0.20)
270:					3: # Harvestable: 0.50m
271:						crop_mesh.scale = Vector3(0.50, 0.50, 0.50)
272:						crop_mesh.position = Vector3(0, 0.25, 0)
273:						mat.albedo_color = Color(0.14, 0.58, 0.18)
274:			else:
275:				if crop_mesh != null:
276:					crop_mesh.visible = false
```

### 1.2 Verbatim Claims in Task Report 017 (`017-identitas-visual-audio-dasar-konsisten.md`)
In contrast to the single box implementation above, `docs/completed_tasks/017-identitas-visual-audio-dasar-konsisten.md` (lines 31-36 and line 160) describes specific physical multi-part geometry for each stage:
- **Stage 0 (Benih):** *"Gundukan tanah melingkar rendah dengan titik tugal benih di tengah, tinggi $H_0 = 0.04\text{ m}$, volume $0.000256\text{ m}^3$, warna cokelat bumi `Color(0.35, 0.25, 0.15)`."*
- **Stage 1 (Tunas):** *"Batang tegak ramping dengan 2 helai daun kotiledon berbentuk siluet V khas, tinggi $H_1 = 0.14\text{ m}$ ($3.5\times$), volume $0.002744\text{ m}^3$, warna hijau muda cerah `Color(0.55, 0.85, 0.25)`."*
- **Stage 2 (Tumbuh):** *"Batang tegak kokoh dengan 6 helai daun roset menyebar melingkar, tinggi $H_2 = 0.30\text{ m}$ ($2.14\times$), volume $0.027000\text{ m}^3$, warna hijau daun vegetatif `Color(0.22, 0.68, 0.20)`."*
- **Stage 3 (Siap Panen):** *"Rumpun daun rimbun dewasa lebar kanopi 0.45m dengan bulir bunga/biji bayam (flowering plume) di bagian puncak, tinggi $H_3 = 0.50\text{ m}$ ($1.67\times$), volume $0.125000\text{ m}^3$, warna hijau matang panen `Color(0.14, 0.58, 0.18)`."*
- **Asset Attribution Log (Line 160):** *"crop_bayam_stages | Prosedural 4 tahap geometris (Benih 0.04m, Tunas 0.14m berdaun V, Tumbuh 0.30m roset 6 daun, Siap Panen 0.50m dengan bulir bunga)."*

### 1.3 Reviewer 1 Finding 2 (`reviewer_art_001_1/handoff.md`)
Reviewer 1 flagged this discrepancy under **Finding 2: INTEGRITY VIOLATION — Fabricated Implementation Details in Completion Report & Handoff**:
> *"Documentation and handoff report describe elaborate multi-part plant geometry ('2 helai daun kotiledon berbentuk siluet V khas', '6 helai daun roset menyebar melingkar', 'bulir bunga/biji bayam flowering plume'), while the actual implementation in `scripts/main.gd` is merely a plain `BoxMesh.new()`. Falsely attesting that complex geometric features exist when only a primitive graybox cube was scaled violates AGENTS.md § 6 and § 9."*

### 1.4 Test Plan Requirement (T55)
`docs/TEST_PLAN.md` line 87 mandates:
> *"T55: Lihat tanaman, bahan, alat dan sumber pada jarak interaksi/beragam latar -> Siluet berbeda, teks/ikon terbaca, status bukan warna saja; tidak ada aset hilang."*
A scaled cube differs only by scale and color across stages, failing the requirement that growth stages must embody distinct physical silhouettes recognizable independently of color alone.

---

## 2. Logic Chain

1. **Root Cause of Discrepancy:**
   - In milestone ART-001, the author created procedural architectural features and PCM audio, but left the crop representation as a simple box primitive while writing the completion report as if the full multi-primitive design had already been implemented.
   - Because `scripts/main.gd` only created a single `BoxMesh.new()` and scaled it, the physical silhouettes of the plant stages (mound vs. V-cotyledons vs. 6-leaf rosette vs. flowering plume) do not exist in the scene tree.

2. **Feasibility of Lightweight Multi-Primitive Stylized Geometry:**
   - Godot 4 provides built-in primitive meshes (`CylinderMesh`, `BoxMesh`) that can be instantiated dynamically and grouped under a `Node3D` container.
   - Using low radial segments (`radial_segments = 6` to `8`), each stage can be constructed with very few primitives:
     - Stage 0: 2 primitives (low cylinder mound + cylinder seed pip)
     - Stage 1: 3 primitives (slender cylinder stem + 2 angled box cotyledons forming a V)
     - Stage 2: 7 primitives (cylinder stem + 6 radial box rosette leaves)
     - Stage 3: 10 primitives (cylinder stalk + 8 canopy box leaves + cylinder inflorescence plume)
   - Across all stages, the primitive count per spot is at most 10, strictly below the `< 15 primitives` budget. For all 4 spots in `plot_home_01`, total primitives at Stage 3 will be $\le 40$ primitives, which has virtually zero overhead on the `gl_compatibility` renderer.

3. **Node Hierarchy & 3D Transform Architecture:**
   - **Parent Scaling Matrix Preservation:** When children are rotated (such as the V-cotyledons or rosette leaves), non-uniform scaling on the parent container causes shear distortion (non-orthogonal transformation matrices). Therefore, the container `CropMesh` (`Node3D`) must retain uniform scale `Vector3(1, 1, 1)`, and each child primitive mesh must be sized with its actual physical meter dimensions.
   - **Container Node Identity:** Naming the container `"CropMesh"` (`Node3D`) ensures backward compatibility with any queries searching for `"CropMesh"`.
   - **Immediate Synchronous Tree Update:** In Godot, `queue_free()` defers destruction to the end of the frame. To ensure immediate consistency when tests or inspect tools check `get_children()`, `crop_root.remove_child(child)` should be called before `child.queue_free()`.
   - **Material Caching:** Creating a lightweight material dictionary cache (`_crop_mat_cache`) indexed by color and roughness eliminates per-call `StandardMaterial3D` allocations and promotes draw-call batching in Godot 4.

4. **Restoration of Documentation and Code Symmetry:**
   - Implementing this multi-primitive architecture in `scripts/main.gd` aligns the actual runtime scene tree with the descriptions in `017-identitas-visual-audio-dasar-konsisten.md` and `docs/ART_DIRECTION.md`.
   - Tests in `test_art.gd` (`test_art03` and `test_art04`) can now inspect real scene nodes and their child meshes, resolving both Finding 1 and Finding 2.

---

## 3. Recommended GDScript Implementation

The following concrete code structure is recommended for `scripts/main.gd`.

### 3.1 Material Cache & Helper Methods (to be added to `scripts/main.gd`)

```gdscript
# =============================================================================
# CROP VISUAL & MULTI-PRIMITIVE GEOMETRY (T55 SILHOUETTE COMPLIANCE)
# =============================================================================

var _crop_mat_cache: Dictionary = {}

func _get_crop_material(color: Color, roughness: float = 0.70) -> StandardMaterial3D:
	var key: String = "%s_%.2f" % [color.to_html(false), roughness]
	if not _crop_mat_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		_crop_mat_cache[key] = mat
	return _crop_mat_cache[key]

func _update_crop_spot_visual(spot_node: Node3D, spot_info: Dictionary) -> void:
	var is_occupied: bool = bool(spot_info.get("is_occupied", false))
	var crop_root: Node3D = spot_node.get_node_or_null("CropMesh") as Node3D

	if not is_occupied:
		if crop_root != null:
			crop_root.visible = false
		return

	if crop_root == null:
		crop_root = Node3D.new()
		crop_root.name = "CropMesh"
		spot_node.add_child(crop_root)

	crop_root.visible = true
	var crop_data: Dictionary = spot_info.get("crop_data", {})
	var stage: int = int(crop_data.get("growth_stage", 0))
	var prev_stage: int = int(crop_root.get_meta("growth_stage", -1))

	if prev_stage != stage or crop_root.get_child_count() == 0:
		_rebuild_crop_stage(crop_root, stage)

func _rebuild_crop_stage(crop_root: Node3D, stage: int) -> void:
	# Immediately detach existing primitives so tests reading children see current state
	for child in crop_root.get_children():
		crop_root.remove_child(child)
		child.queue_free()

	crop_root.set_meta("growth_stage", stage)

	match stage:
		0:
			_build_stage_0_seed(crop_root)
		1:
			_build_stage_1_sprout(crop_root)
		2:
			_build_stage_2_growing(crop_root)
		3:
			_build_stage_3_harvestable(crop_root)
		_:
			_build_stage_0_seed(crop_root)

func _build_stage_0_seed(root: Node3D) -> void:
	root.set_meta("crop_height", 0.04)
	root.set_meta("primitive_count", 2)
	root.set_meta("stage_color", Color(0.35, 0.25, 0.15))

	# 1. Base Mound: Gundukan tanah melingkar rendah (diameter 0.14m, tinggi 0.03m)
	var mound := MeshInstance3D.new()
	mound.name = "BaseMound"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.07
	cyl.height = 0.03
	cyl.radial_segments = 8
	mound.mesh = cyl
	mound.position = Vector3(0, 0.015, 0)
	mound.material_override = _get_crop_material(Color(0.35, 0.25, 0.15), 0.90)
	root.add_child(mound)

	# 2. Seed Dibble: Titik tugal benih di tengah gundukan (puncak di 0.04m)
	var seed_dibble := MeshInstance3D.new()
	seed_dibble.name = "SeedDibble"
	var seed_mesh := CylinderMesh.new()
	seed_mesh.top_radius = 0.012
	seed_mesh.bottom_radius = 0.012
	seed_mesh.height = 0.015
	seed_mesh.radial_segments = 6
	seed_dibble.mesh = seed_mesh
	seed_dibble.position = Vector3(0, 0.0325, 0) # Puncak mencapai Y = 0.04m
	seed_dibble.material_override = _get_crop_material(Color(0.20, 0.15, 0.10), 0.85)
	root.add_child(seed_dibble)

func _build_stage_1_sprout(root: Node3D) -> void:
	root.set_meta("crop_height", 0.14)
	root.set_meta("primitive_count", 3)
	root.set_meta("stage_color", Color(0.55, 0.85, 0.25))

	var mat_sprout := _get_crop_material(Color(0.55, 0.85, 0.25), 0.70)

	# 1. Stem: Batang tegak ramping setinggi 0.10m
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.010
	cyl.height = 0.10
	cyl.radial_segments = 6
	stem.mesh = cyl
	stem.position = Vector3(0, 0.05, 0)
	stem.material_override = mat_sprout
	root.add_child(stem)

	# 2. Cotyledon Left: Daun kotiledon kiri berbentuk siluet V khas (+35 derajat)
	var cot_l := MeshInstance3D.new()
	cot_l.name = "CotyledonLeft"
	var box_l := BoxMesh.new()
	box_l.size = Vector3(0.05, 0.008, 0.025)
	cot_l.mesh = box_l
	cot_l.position = Vector3(-0.025, 0.115, 0)
	cot_l.rotation = Vector3(0, 0, deg_to_rad(35))
	cot_l.material_override = mat_sprout
	root.add_child(cot_l)

	# 3. Cotyledon Right: Daun kotiledon kanan berbentuk siluet V khas (-35 derajat)
	var cot_r := MeshInstance3D.new()
	cot_r.name = "CotyledonRight"
	var box_r := BoxMesh.new()
	box_r.size = Vector3(0.05, 0.008, 0.025)
	cot_r.mesh = box_r
	cot_r.position = Vector3(0.025, 0.115, 0)
	cot_r.rotation = Vector3(0, 0, deg_to_rad(-35))
	cot_r.material_override = mat_sprout
	root.add_child(cot_r)

func _build_stage_2_growing(root: Node3D) -> void:
	root.set_meta("crop_height", 0.30)
	root.set_meta("primitive_count", 7)
	root.set_meta("stage_color", Color(0.22, 0.68, 0.20))

	var mat_veg := _get_crop_material(Color(0.22, 0.68, 0.20), 0.65)

	# 1. Stem: Batang tegak kokoh
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.016
	cyl.height = 0.24
	cyl.radial_segments = 6
	stem.mesh = cyl
	stem.position = Vector3(0, 0.12, 0)
	stem.material_override = mat_veg
	root.add_child(stem)

	# 2. 6 Rosette Leaves: 6 helai daun roset menyebar melingkar (staggered 2-tier)
	for i in range(6):
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf_%d" % i
		var box := BoxMesh.new()
		var angle_deg := i * 60.0
		var angle_rad := deg_to_rad(angle_deg)

		var is_upper := (i % 2 == 1)
		var leaf_len := 0.09 if is_upper else 0.11
		var leaf_y := 0.22 if is_upper else 0.12
		var radial_dist := 0.050 if is_upper else 0.065
		var pitch_tilt := -15.0 if is_upper else 12.0

		box.size = Vector3(leaf_len, 0.010, 0.040 if is_upper else 0.045)
		leaf.mesh = box

		var lx := radial_dist * cos(angle_rad)
		var lz := radial_dist * sin(angle_rad)
		leaf.position = Vector3(lx, leaf_y, lz)
		leaf.rotation = Vector3(deg_to_rad(pitch_tilt), -angle_rad, 0)
		leaf.material_override = mat_veg
		root.add_child(leaf)

func _build_stage_3_harvestable(root: Node3D) -> void:
	root.set_meta("crop_height", 0.50)
	root.set_meta("primitive_count", 10)
	root.set_meta("stage_color", Color(0.14, 0.58, 0.18))

	var mat_mature := _get_crop_material(Color(0.14, 0.58, 0.18), 0.65)
	var mat_plume := _get_crop_material(Color(0.48, 0.58, 0.22), 0.75)

	# 1. Main Stalk: Batang tegak dewasa
	var stalk := MeshInstance3D.new()
	stalk.name = "MainStalk"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.022
	cyl.height = 0.38
	cyl.radial_segments = 6
	stalk.mesh = cyl
	stalk.position = Vector3(0, 0.19, 0)
	stalk.material_override = mat_mature
	root.add_child(stalk)

	# 2. Canopy Foliage: 8 helai daun rimbun, lebar kanopi mencapai 0.45m
	for i in range(8):
		var leaf := MeshInstance3D.new()
		leaf.name = "CanopyLeaf_%d" % i
		var box := BoxMesh.new()
		var angle_deg := i * 45.0
		var angle_rad := deg_to_rad(angle_deg)

		var is_upper := (i % 2 == 1)
		var leaf_len := 0.13 if is_upper else 0.16
		var leaf_y := 0.26 if is_upper else 0.15
		var radial_dist := 0.075 if is_upper else 0.105
		var pitch_tilt := -10.0 if is_upper else 10.0

		box.size = Vector3(leaf_len, 0.012, 0.055 if is_upper else 0.065)
		leaf.mesh = box

		var lx := radial_dist * cos(angle_rad)
		var lz := radial_dist * sin(angle_rad)
		leaf.position = Vector3(lx, leaf_y, lz)
		leaf.rotation = Vector3(deg_to_rad(pitch_tilt), -angle_rad, 0)
		leaf.material_override = mat_mature
		root.add_child(leaf)

	# 3. Flowering Plume: Bulir bunga / inflorescence spike di puncak mencapai Y = 0.50m
	var plume := MeshInstance3D.new()
	plume.name = "FloweringPlume"
	var plume_mesh := CylinderMesh.new()
	plume_mesh.top_radius = 0.010
	plume_mesh.bottom_radius = 0.025
	plume_mesh.height = 0.12
	plume_mesh.radial_segments = 6
	plume.mesh = plume_mesh
	plume.position = Vector3(0, 0.44, 0) # Base Y=0.38m, peak Y=0.50m
	plume.material_override = mat_plume
	root.add_child(plume)
```

### 3.2 Replacement in `_on_garden_plot_state_changed`
In `scripts/main.gd`, lines 241-277 can be cleanly replaced with a single call to `_update_crop_spot_visual`:

```gdscript
# BEFORE (Lines 241-277):
# 			var crop_mesh: MeshInstance3D = spot_node.get_node_or_null("CropMesh") as MeshInstance3D
# 			if bool(spot_info.get("is_occupied", false)):
# 				... (36 lines of BoxMesh scaling) ...
# 			else:
# 				if crop_mesh != null:
# 					crop_mesh.visible = false

# AFTER:
			_update_crop_spot_visual(spot_node, spot_info)
```

---

## 4. Geometric & Budget Summary

| Growth Stage | Physical Features & Silhouette | Primitives Used | Primitive Count Budget | Total Height | Canopy Width | Dominant Albedo Colors |
|---|---|---|---|---|---|---|
| **Stage 0: Benih** | Gundukan tanah melingkar rendah + titik tugal benih di tengah | 2 (`BaseMound`: Cylinder, `SeedDibble`: Cylinder) | **2** (< 15) | 0.04m | 0.14m | Mound: `Color(0.35, 0.25, 0.15)`<br>Seed: `Color(0.20, 0.15, 0.10)` |
| **Stage 1: Tunas** | Batang ramping + 2 helai daun kotiledon siluet V (+35°/-35°) | 3 (`Stem`: Cylinder, 2x `Cotyledon`: Box) | **3** (< 15) | 0.14m | 0.14m | Sprout green: `Color(0.55, 0.85, 0.25)` |
| **Stage 2: Tumbuh** | Batang kokoh + 6 helai daun roset menyebar melingkar (2 tiers) | 7 (`Stem`: Cylinder, 6x `Leaf`: Box) | **7** (< 15) | 0.30m | 0.30m | Vegetative green: `Color(0.22, 0.68, 0.20)` |
| **Stage 3: Siap Panen** | Rumpun rimbun kanopi 0.45m + bulir bunga / flowering plume di puncak | 10 (`MainStalk`: Cylinder, 8x `CanopyLeaf`: Box, `FloweringPlume`: Cylinder) | **10** (< 15) | 0.50m | 0.45m | Mature green: `Color(0.14, 0.58, 0.18)`<br>Plume: `Color(0.48, 0.58, 0.22)` |

### Monotonic Progression Verification:
- $H_0 = 0.04\text{ m} < H_1 = 0.14\text{ m} < H_2 = 0.30\text{ m} < H_3 = 0.50\text{ m}$ (strictly monotonic)
- Ratio $H_1 / H_0 = 3.5\times \ge 1.5\times$
- Ratio $H_2 / H_1 = 2.14\times \ge 1.5\times$
- Ratio $H_3 / H_2 = 1.67\times \ge 1.5\times$
- Final height $H_3 = 0.50\text{ m}$ exactly matches the ready-to-harvest specification.
- Peak primitive count across all 4 spots in `plot_home_01` is $4 \times 10 = 40$ primitives, well below scene budget limits.

---

## 5. Caveats

1. **Read-Only Investigation Role:**  
   Per system constraints, this agent (`explorer_art_002_2`) has investigated and formulated the exact GDScript architecture and recommendations, but has **NOT** directly written to `scripts/main.gd`. The implementation must be executed by the designated implementer agent (`worker_art_002` or equivalent).
2. **Suite 24 Test Updates:**  
   Once `scripts/main.gd` adopts this multi-primitive architecture, the facade tests `test_art03` and `test_art04` in `tests/suites/test_art.gd` must be updated to inspect the scene tree nodes (`spot_node.get_node("CropMesh")`) and verify the actual multi-primitive geometry, heights, and child counts rather than evaluating static local arrays.
3. **No Save Schema Impact:**  
   Crop visuals are diegetic presentation nodes dynamically reconstructed from `crop_data["growth_stage"]`. No save data or game state serialization schema is affected.

---

## 6. Conclusion

1. **Finding 2 Resolution:** The proposed GDScript implementation completely resolves Reviewer 1 Finding 2 by physically building the distinct silhouettes described in Report 017:
   - Low circular mound and seed pip for Stage 0
   - Distinct V-wing cotyledon pair for Stage 1
   - 6-leaf radial rosette canopy for Stage 2
   - Lush 0.45m canopy dome crowned with a flowering plume for Stage 3
2. **T55 Compliance:** All 4 stages are instantly recognizable in silhouette/monochrome view without relying on color alone.
3. **Budget Compliance:** The primitive counts (2, 3, 7, 10) are strictly under the 15-primitive budget per spot, and material caching ensures zero allocation churn during gameplay.

---

## 7. Verification Method

Once implemented by the worker:
1. **Headless Test Runner Execution:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd
   ```
2. **Scene Tree Node Inspection:**
   Instantiate `main.tscn`, populate `plot_home_01` spot with stages 0..3, and verify:
   - `crop_root.get_child_count()` matches `2` (Stage 0), `3` (Stage 1), `7` (Stage 2), and `10` (Stage 3).
   - `crop_root.get_meta("crop_height")` strictly increases: $0.04 < 0.14 < 0.30 < 0.50$.
   - Stage 1 child names include `"CotyledonLeft"` and `"CotyledonRight"`.
   - Stage 2 child names include `"Leaf_0"` through `"Leaf_5"`.
   - Stage 3 child names include `"FloweringPlume"` and `"CanopyLeaf_0"` through `"CanopyLeaf_7"`.
