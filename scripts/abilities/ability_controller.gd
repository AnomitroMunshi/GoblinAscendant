class_name AbilityController
extends Node
## Executes equipped essence abilities for the player.
## OWNER: Progression & Quest agent. (Lead stub: public API only.)
## The Player creates one as a child and calls setup(self), then
## try_activate(slot) on ability_1/2/3. UI reads cooldowns via
## GameState.ability_controller.

var player: Node3D


func setup(p_player: Node3D) -> void:
	player = p_player
	GameState.ability_controller = self


func try_activate(_slot: int) -> bool: return false
func get_ability_id(slot: int) -> StringName: return Progression.get_equipped(slot)
func get_cooldown_remaining(_slot: int) -> float: return 0.0
func get_cooldown_total(_slot: int) -> float: return 0.0
func get_energy_cost(_slot: int) -> float: return 0.0
