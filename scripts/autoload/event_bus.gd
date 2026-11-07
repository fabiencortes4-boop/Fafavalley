extends Node
## Bus d'événements global : les systèmes communiquent sans se connaître.

signal toast_requested(text: String)
signal inventory_changed
signal gold_changed(amount: int)
signal energy_changed(value: int, max_value: int)
signal water_changed(value: int, max_value: int)
signal farm_tile_changed(cell: Vector2i)
signal passed_out
signal day_summary(report: Dictionary)
signal shop_requested
signal sleep_requested
signal before_save
signal map_change_requested(map_id: String, cell: Vector2i)
signal message_requested(title: String, text: String)
signal dialogue_requested(npc_id: String, text: String)
signal relations_changed
signal health_changed(value: int, max_value: int)
signal player_fainted
signal eat_requested(item_id: String)
signal elevator_requested(levels: Array)
signal forge_requested
signal chest_requested(cell: Vector2i)
signal mail_requested
signal camera_shake(strength: float, duration: float)
signal kitchen_requested
signal shop_opened(shop_id: String)
signal animals_requested(building: String)
signal zone_entered(name: String)
## Un chapitre de l'histoire est terminé (par la voie indiquée)
## Combat (pour la vue 3D) : coup porté, monstre vaincu, joueur touché
signal combat_hit(monster: Node2D, amount: int)
signal monster_killed(at: Vector2, kind: String)
signal player_hurt(from: Vector2)
## Une scène de cœur avec un habitant
signal heart_scene_requested(npc_id: String, scene: Dictionary)
## Le tableau des demandes (place du village)
signal board_requested
## Le stand de la fête ou du marché, sur la place
signal booth_requested
signal story_advanced(chapter_id: String, path_label: String)
signal npc_bubble(npc_id: String, text: String)
## Un poisson légendaire est pêché
signal legendary_fish(fish_id: String)


func toast(text: String) -> void:
	toast_requested.emit(text)
