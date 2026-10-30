extends SceneTree
func _initialize() -> void:
	for w in ["castle/tower-square-base","castle/tower-square-mid","castle/tower-square-mid-windows","castle/tower-square-top","castle/tower-square-roof","castle/tower-square-top-roof","castle/tower-square-top-roof-high","castle/tower-hexagon-base","castle/tower-hexagon-mid","castle/tower-hexagon-roof","castle/tower-hexagon-top","castle/wall-doorway","castle/gate","castle/wall-half","castle/wall-narrow","castle/wall-narrow-gate","castle/wall-corner","castle/wall-pillar","castle/flag-wide","castle/flag-banner-long","castle/door","castle/siege-trebuchet","castle/ground","town/roof-gable","town/roof-high-gable","town/roof-gable-end","town/roof-gable-top","town/roof-high-gable-end","town/wall-window-shutters","town/wall-wood-window-shutters","town/wall-door","town/wall-doorway-square","town/wall-corner","town/pillar-stone","town/pillar-wood","town/overhang","town/balcony-wall","town/stall-red","town/stall-green","town/fountain-round-detail","town/windmill","town/hedge","town/lantern","town/cart-high","town/banner-green","town/tree-high-round","town/road-corner","town/planks","town/wall-wood-corner","town/watermill","town/wall-half"]:
		var kv: PackedStringArray = w.split("/")
		if not ResourceLoader.exists(Kenney.path(kv[0], kv[1])):
			print(w, " MISSING"); continue
		var m: Mesh = Kenney.merged(kv[0], kv[1])
		var a: AABB = m.get_aabb()
		print(w, " pos=", a.position, " size=", a.size)
	quit()
