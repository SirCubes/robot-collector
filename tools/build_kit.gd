extends SceneTree

# Собирает MeshLibrary для GridMap из набора деталей models/kit.glb.
# Формы столкновений — простые коробки по размеру детали: на стыках соседних
# плит робот не спотыкается. Пандус и лестница — выпуклая форма по самой модели.
# Иконки берутся из kit/previews/<имя>.png, если такие есть.
# Номера деталей стабильны: у старых деталей номер берётся из прежней библиотеки,
# новые получают следующие свободные — уровни на GridMap не «перемешиваются».
#
# Запуск (после правок набора в Blender):
#   Godot.exe --headless --path D:\Games\MyGame --script res://tools/build_kit.gd

const SOURCE := "res://models/kit.glb"
const OUTPUT := "res://kit/kit_library.tres"
const PREVIEWS := "res://kit/previews/"
# Детали, у которых форма — выпуклая оболочка модели, а не коробка
const CONVEX := ["ramp"]
# Лестница: вместо ступенек — гладкий наклон 34° (на уступы робот не забирается).
# Поднимается к -Z, как и модель: от низа ближнего края к верхней ступеньке.
const STAIRS_RAMP := [
	Vector3(-1, -0.5, 1), Vector3(1, -0.5, 1), Vector3(-1, -0.5, -1), Vector3(1, -0.5, -1),
	Vector3(-1, 0.5, -0.5), Vector3(1, 0.5, -0.5), Vector3(-1, 0.5, -1), Vector3(1, 0.5, -1)]
# Детали без формы столкновений (чистый декор, сквозь них можно пройти)
const NO_COLLISION := ["crystals"]
# Нижняя граница формы: у парящих плит скала снизу — только для красоты
const MIN_BOTTOM := {"floating_tile": 0.0, "floating_tile_dirt": 0.0}

func _init() -> void:
	# Номера деталей из прежней библиотеки
	var old_ids := {}
	if ResourceLoader.exists(OUTPUT):
		var old: MeshLibrary = load(OUTPUT)
		for old_id in old.get_item_list():
			old_ids[old.get_item_name(old_id)] = old_id
	var next_id := 0
	for old_id in old_ids.values():
		next_id = max(next_id, old_id + 1)

	var scene: Node = load(SOURCE).instantiate()
	var lib := MeshLibrary.new()
	for child in scene.get_children():
		if not child is MeshInstance3D:
			continue
		var mi: MeshInstance3D = child
		var item_name := String(mi.name)
		var id: int
		if old_ids.has(item_name):
			id = old_ids[item_name]
		else:
			id = next_id
			next_id += 1
		lib.create_item(id)
		lib.set_item_name(id, item_name)
		lib.set_item_mesh(id, mi.mesh)

		# Формы столкновений: пары [форма, положение]
		var shapes := []
		if item_name in NO_COLLISION:
			pass
		elif item_name == "stone_stairs":
			var ramp := ConvexPolygonShape3D.new()
			ramp.points = PackedVector3Array(STAIRS_RAMP)
			shapes.append(ramp)
			shapes.append(Transform3D.IDENTITY)
		elif item_name in CONVEX:
			shapes.append(mi.mesh.create_convex_shape())
			shapes.append(Transform3D.IDENTITY)
		else:
			var box := mi.mesh.get_aabb()
			if MIN_BOTTOM.has(item_name):
				var bottom: float = MIN_BOTTOM[item_name]
				box.size.y = box.end.y - bottom
				box.position.y = bottom
			var shape := BoxShape3D.new()
			shape.size = box.size
			shapes.append(shape)
			shapes.append(Transform3D(Basis.IDENTITY, box.get_center()))
		lib.set_item_shapes(id, shapes)

		var preview_path := PREVIEWS + item_name + ".png"
		if ResourceLoader.exists(preview_path):
			lib.set_item_preview(id, load(preview_path))

		print("  %d: %s (%d shape)" % [id, item_name, shapes.size() / 2])

	# Сохраняем прежний UID, чтобы сцены с GridMap не теряли ссылку на библиотеку
	var old_uid := ResourceLoader.get_resource_uid(OUTPUT) if ResourceLoader.exists(OUTPUT) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(lib, OUTPUT)
	if old_uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUTPUT, old_uid)
	print("Saved %d items to %s, error code %d" % [lib.get_item_list().size(), OUTPUT, err])
	scene.free()
	quit()
