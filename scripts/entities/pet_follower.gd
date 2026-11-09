class_name PetFollower
extends Critter
## Le compagnon du joueur : il le suit à quelques pas dehors ; à la maison,
## il dort près du lit (ou au coin du feu en hiver).

var player: Node2D
var follow: bool = true


func _process(delta: float) -> void:
	if not follow or player == null or not is_instance_valid(player):
		return
	var behind := player.position - Vector2(player.get("facing")) * 14.0 + Vector2(6, 0)
	var to := behind - position
	if to.length() > 160.0:
		position = behind  # resté loin (changement de carte, téléportation)
		return
	if to.length() > 10.0:
		position += to.normalized() * minf(to.length() * 4.0, 95.0) * delta
