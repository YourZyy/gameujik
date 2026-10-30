extends SceneTree

func _init() -> void:
	print("[BUILD_UI] Generating scenes/ui/interaction_prompt.tscn...")
	var err = generate_prompt_scene()
	if err == OK:
		print("[BUILD_UI] Successfully generated interaction_prompt.tscn!")
		quit(0)
	else:
		printerr("[BUILD_UI] Failed to generate interaction_prompt.tscn: ", err)
		quit(1)

func generate_prompt_scene() -> Error:
	var root = CanvasLayer.new()
	root.name = "InteractionPrompt"
	root.layer = 1
	var script = load("res://scripts/ui/interaction_prompt.gd")
	root.set_script(script)

	var root_control = Control.new()
	root_control.name = "RootControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(root_control)

	var reticle = ColorRect.new()
	reticle.name = "Reticle"
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -2.0
	reticle.offset_top = -2.0
	reticle.offset_right = 2.0
	reticle.offset_bottom = 2.0
	reticle.color = Color(1.0, 1.0, 1.0, 0.85)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(reticle)

	var prompt_panel = PanelContainer.new()
	prompt_panel.name = "PromptPanel"
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	prompt_panel.offset_left = -60.0
	prompt_panel.offset_top = 36.0
	prompt_panel.offset_right = 60.0
	prompt_panel.offset_bottom = 72.0
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.75)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	prompt_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(prompt_panel)

	var prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "[E] Interaksi"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.add_child(prompt_label)

	set_owner_recursive(root, root)

	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root)
	if pack_err != OK:
		printerr("Error packing interaction_prompt scene: ", pack_err)
		return pack_err

	var dir = DirAccess.open("res://")
	if not dir.dir_exists("scenes/ui"):
		dir.make_dir_recursive("scenes/ui")

	var save_err = ResourceSaver.save(packed_scene, "res://scenes/ui/interaction_prompt.tscn")
	root.free()
	return save_err

func set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		set_owner_recursive(child, new_owner)
