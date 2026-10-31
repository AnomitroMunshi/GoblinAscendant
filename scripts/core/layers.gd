class_name Layers
## Physics layer bitmasks. Matches [layer_names] in project.godot.

const WORLD := 1        # terrain, rocks, trunks, ruins, cave walls (camera collides with this)
const PLAYER := 2       # player body
const ACTORS := 4       # enemies, NPCs, friend, boss
const HITBOX := 8       # attack Areas (monitor only)
const INTERACT := 16    # Interactable areas
const TRIGGER := 32     # TriggerZone areas
const WATER := 64       # water volumes (Area3D, for footstep/splash/speed)
const TREES := 128      # trunks, fallen logs, stumps: block bodies, sight and projectiles, but NOT the
                        # camera, so a dense forest never snaps the SpringArm in front of the player
