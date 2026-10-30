class_name Svc
extends RefCounted
## Looks up autoloads by name so scripts that tests compile stand-alone do not name them directly.


static func node(autoload_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(autoload_name) if tree != null else null
