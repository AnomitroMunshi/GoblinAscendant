# Chapter 1 — A Fire of Our Own

Story draft and implementation handoff • 2026-10-31

## Status and scope

This document develops the existing five-quest Chapter 1 into a narrative. New scenes, dialogue, props and interactions below are writing specifications, not claims of implemented features. Claude or another implementer should inspect the current game before adding them. Preserve unrelated work.

Existing quest IDs and objectives are in `scripts/quests/quest_data.gd`. Use those IDs where possible. The current code ends with level 5 and Hobgoblin evolution; this draft proposes ending at the claimed hearth, with evolution foreshadowed instead. That ending change requires explicit implementation and reconciliation with progression, completion events and saves. Until then, the current game still has its old ending.

First-build scope: Goblin protagonist; knife, sword, sling and unarmed combat. Starting possessions remain a rough knife and opaque torn waist cloth, with bare chest and feet. Weapons and clothing are earned separately. The user's subsequent direction adds deer/rabbit encounters and an adventurer search-party avoidance scene on the journey to Nib, detailed below. These are new implementation requirements; the broader ambient wildlife library remains deferred. Do not add an axe, a Hobgoblin model or extra companion mechanics merely to implement this story.

The protagonist's name, wider origin and eventual evolution lore remain open. Nib is an adult goblin and an established friend, with practical skills and judgment of his own. Neither character knows the valley's full history.

## Story promise

Two displaced goblins try to make a home in a valley where every safe place seems to belong to someone stronger. The player grows capable through exploring, fighting and choosing to return for a friend. The chapter begins with an extinguished shelter and ends with a deliberately tended fire.

Keep the fantasy grounded in wet clothes, empty stomachs, old masonry and the effort of surviving. Let danger have weight without filling every scene with cruelty. Peaceful people are not targets; species alone does not establish guilt. Avoid a prophecy, a royal lineage or a voice announcing that the protagonist is chosen.

## Before the opening

For several weeks, the protagonist and Nib have shared a makeshift shelter near the southern marsh. The protagonist hunts and scouts; Nib repairs baskets, gathers food and knows how to coax a fire from poor fuel. Their arrangement has become a friendship without either making a speech about it.

A local raiding band discovers the shelter. They take food and tools, set the reed roof alight and pursue the two goblins when they flee. The protagonist draws pursuit toward the flooded ground and loses consciousness beneath a fallen tree. Nib circles back to recover their supply basket and is captured.

Reveal this in small pieces after control begins. No playable massacre or lengthy opening cinematic is required. Establish only two known survivors; do not invent a destroyed village or dead relatives without a later story decision.

## 1. A Small Beginning

Existing ID: `a_small_beginning`.

### Opening scene

Rain had filled the footprints before he woke.

The goblin lay beneath the roots of a fallen tree, his cheek pressed into cold mud. When he tried to breathe deeply, pain tightened beneath his ribs. He stayed still until it eased.

His knife was there. He checked it twice.

Across the reeds, a thin column of smoke rose from the place where their shelter had stood. He watched it for movement. Nib would have complained about the wet wood. He would have crouched close to the embers, muttering, refusing to let them die.

Nothing moved.

The goblin pushed himself upright.

### Playable details

- Begin in the existing glade. A fallen trunk, rain-dark ground and distant smoke can imply the escape without adding a new map region. Show the smoke toward the marsh only where it fits the established layout.
- Give the player a quiet moment to move and inspect the knife. Avoid starting with a tutorial modal over the opening image.
- Beside the route, a broken woven basket contains a piece of blue scarf caught in its handle. Nib uses that colour in his existing design. This is a recognition clue, not a magical tracking object.
- Near the westbound signpost, smaller footprints join boot prints. A shallow drag mark begins where Nib's injured leg gave way. Rain makes the evidence incomplete, but the direction is readable.
- Keep the signpost as the existing interaction. Its warning about raiders provides context; the scarf and tracks provide the personal reason to go west.

Suggested brief protagonist line: “You came back for the basket.”

Objective text: “Search the glade for Nib's trail,” then “Follow the trail into the western woods.” Do not require a trail-detection system; visible props and the existing objective marker are enough.

## The journey to Nib — a living valley

Added at the user's request. The walk from the glade to the rescue should let the player discover ordinary life, then understand why a small goblin must move carefully through it. Keep the established westbound route and fit these beats to the actual terrain. Do not place every encounter within sight of the signpost.

### Leaving the glade

Water drips from the fallen tree long after the rain has eased. Ferns lean across the path, their tips bright with droplets. The goblin's first steps leave dark impressions in the soft earth. Beyond the glade, wind moves through the upper branches while the undergrowth stays almost still.

The smoke from the ruined shelter disappears behind the trees. Ahead, the woods contain smaller sounds: insects over standing water, a bird tapping at bark, the occasional drop striking a broad leaf. Nib's trail is visible in interruptions to this ordinary ground—a bent fern, disturbed mud, the blue thread on a thorn.

Give the player room to look around. A distant objective marker can guide without replacing the physical trail. Ambient birds and insects can be sound alone; they do not require additional animal actors.

### The rabbit

Beside a root, a rabbit feeds on low leaves. It is easy to miss until an ear turns toward the player. If the goblin pauses at a distance, it returns briefly to feeding. When he comes too close, it freezes, then darts beneath the brambles. The leaves shake after it has vanished.

The protagonist stops with one foot raised. For a moment he listens as intently as the rabbit did.

No dialogue or reward is needed. This is the first small demonstration that nearby creatures notice the player. It should not become a hunting tutorial while Nib needs help.

Implementation: one rabbit encounter with idle, alert and flee behaviour, using a short safe escape route and a concealed endpoint. Distance and visible approach are sufficient for the first version; do not claim a general sound-detection system. Trigger once per journey state, not every time the player crosses an invisible line. Never despawn it visibly in open ground.

### The deer crossing

At a shallow runnel, the path opens between two stands of trees. A deer steps out ahead, placing its feet carefully on the stones. It lowers its muzzle to the water, then raises its head. Water drops from its chin.

For a few breaths, it watches the goblin.

If the player stays back, the deer crosses and disappears uphill at a walk. If the player rushes toward it, it wheels away and bounds into the trees. The encounter continues naturally if ignored; it never locks the camera or blocks the route.

Beyond the crossing, a boot print cuts through the deer's tracks. Another has crushed the edge of a mushroom. The player hears a human voice before seeing its owner.

Implementation: one deer with a grounded crossing route, an alert pause and a separate flee route. Place it far enough ahead to be noticed before proximity triggers flight. Spawn out of view or activate an already placed actor; avoid animals appearing beside the player. Keep rabbit and deer away from the rescue arena and navigation hazards. No hunting, loot or persistent ecosystem is required for these scenes.

### The dead wolves

Before the player sees the adventurers, the smell reaches him: wet fur and fresh blood. Two wolves lie beside the trail. One has fallen across the roots of a beech; the other lies near a snapped branch, its paws sunk into churned mud. Neither moves.

A crossbow bolt protrudes from the first wolf's flank. A clean blade wound marks the second. Human boot prints surround both bodies, and a strip of bloodied binding cloth has been discarded beside a stone. These were killed recently by an armed party, not by the goblin or another animal.

The protagonist crouches near a print without touching the carcass. Beyond it, the same boot tread continues toward human voices. He moves off the open trail.

Do not present the wolves as trophies or automatically frame the adventurers as cruel. The disturbed ground suggests a fight; the overheard conversation confirms who killed them without settling every detail of how it started.

### Scavenging the aftermath

The player can search the wolves. Beside the second carcass, a short sword lies half-hidden beneath the snapped branch. Its blade is nicked, its point slightly bent and its leather grip splitting at the seam. Mud fills the shallow maker's stamp. It is a rough, worn weapon, small enough for the goblin to use in one hand.

The sword belonged to one of the adventurers. It twisted when it struck the roots during the fight, and its owner discarded it after drawing a spare. It remains serviceable for the goblin, although the damage makes it less reliable than a sound blade. Keep the bend modest: this must look like a usable battered sword, not a broken object that inexplicably functions perfectly.

The goblin lifts it by the grip and tests its weight close to the ground. It reaches farther than his knife. Beyond the trees, a voice carries back along the path.

> **Lookout:** “Leaving your blade?”
>
> **Third adventurer:** “Bent it on the roots. I've a spare. Keep moving.”

This confirms that the weapon was abandoned. Taking it does not count as stealing from a neutral NPC and must not trigger hostility. The player may leave it untouched and continue with the starting knife.

Suggested interactions:

| Target | Prompt | Result |
|---|---|---|
| First wolf carcass | Search wolf | Find one usable wolf fang; record this carcass as searched. |
| Second wolf carcass | Search wolf | Find one usable wolf fang; record this carcass as searched. |
| Discarded sword | Take battered short sword | Acquire the optional one-handed main weapon and show a brief equip/stow choice or existing compatible inventory action. |

Wolf fangs are small scavenged materials with a clear inventory description: “A sound fang recovered from a dead wolf. May be useful for trade or crafting later.” Their future use is a plan, not a working crafting or merchant system. Do not award meat that implies a missing cooking system, or a full hide instantly removed without tools. A brief search is sufficient for these fangs; detailed harvesting can come later.

Item presentation: **Battered Short Sword** — “A discarded adventurer's blade. Chipped edge, worn grip, slight bend. Still long enough to keep teeth away.” It offers a different reach and moveset from the rough knife, with tuning left to the combat implementation. Do not promise a flat damage upgrade, durability simulation or random item statistics. The knife remains owned and available in its separate carried slot. Drawing the sword stows the knife; this is not dual wielding. If immediately equipped, show a believable handoff/stow rather than two weapons occupying the same hand. A simple earned carrying loop may be included with the pickup if needed for the visible stowed sword; do not silently grant a full belt or outfit.

Implementation: place two authored wolf carcasses along the approach, with restrained blood and readable weapon evidence. Use existing wolf geometry where possible. They are already dead: no attack AI, target lock, repeat death signals, XP, player kill/achievement credit or essence rewards. Add explicit search interactions and the separate sword pickup. Use stable unique IDs for each searched carcass and the sword; persist their states and inventory ownership so reloads cannot duplicate loot. Keep carcass state stable and avoid overlapping live spawns at these positions.

The sword needs a real item/equip path, visible model, one-handed sword moveset and matching reach/contact windows. An inventory string alone does not complete this requirement. Preserve Goblin slot restrictions, the separate starting knife, unarmed/holster behaviour and save restoration. If supporting equipment systems are incomplete, report the missing pieces and implement them within this pickup's scope rather than claiming the sword is usable. No full crafting, trading or general animal-harvesting system is required.

### Adventurers on the trail

Through the brush, three adventurers inspect the muddy path. One kneels beside the prints. Another watches the treeline with a weapon ready. The third holds a folded notice whose markings are too far away to read.

> **Lookout:** “Two wolves down. How many more?”
>
> **Tracker:** “Can't tell. Stay together this time.”
>
> **Third adventurer:** “And leave the bodies. We still have ground to cover.”

The tracker shifts attention to smaller prints crossing the disturbed ground.

> **Tracker:** “Two sets. Small feet. One dragging.”
>
> **Lookout:** “Raiders?”
>
> **Tracker:** “Could be. Could be running from them.”
>
> **Third adventurer:** “Captain wants the road clear before dark. Check the hollow.”

The goblin looks down at his own bare feet. He cannot know whether they would listen before drawing steel. Across the path, the ferns grow thick beneath a fallen trunk.

This encounter should invite the player to leave the open trail, wait behind solid cover and pass along a shallow side route while the party searches. Boots and conversation tell the player where the adventurers are even when branches conceal them. A gap in the cover offers a brief view of their backs before the player moves on.

> **Lookout, farther away:** “Something moved.”
>
> **Tracker:** “Rabbit. Keep looking.”

Use that exchange as authored background dialogue only when the party has not actually detected the player. Do not have an NPC dismiss a goblin standing in plain sight as a rabbit.

After the voices recede, the player rejoins Nib's trail beside a scrap of blue cloth. The next distant sound is a guard laughing at the rescue site. Ordinary forest noise falls away gradually as the player approaches the captors.

### Encounter rules and continuity

- The story intends an avoidance route, not a mandatory fight against the adventurers. Provide reliable terrain cover and enough time to observe their movement. Do not force a cinematic capture or an instant-fail stealth restart.
- Keep the existing camp trio neutral unless existing faction behaviour already justifies aggression. A monster-searching patrol does not authorize making every adventurer hostile or awarding rewards for killing peaceful humans.
- Reuse the existing three adventurers for the first version, staging their search before they return to camp. Do not create duplicate versions at the camp and on the path. Their return can happen offscreen; loading must preserve a sensible encounter state.
- If discovered while the trio remains neutral, the lookout challenges the player: “Out of the brush. Slowly.” The goblin can back away or use the side path after a warning. Discovery must not automatically become lethal combat. A later expressly hostile patrol would require its own faction and story decision.
- “Hide” must correspond to actual behaviour. Solid trunks, rocks and terrain can block line of sight. Decorative foliage is not automatically cover; only advertise concealment in bushes if detection actually supports it. Do not tell the player to crouch until a crouch action and appropriate movement exist.
- The first implementation can use existing movement, LOS checks and a short authored patrol. A full stealth meter, noise simulation, takedowns and complex suspicion system are unnecessary. Add a readable warning and consistent discovery response if those are missing.
- Nib's rescue remains reachable if the wildlife is missed, the player takes another path, the patrol scene was already seen, or the player is spotted. Wildlife and optional dialogue never gate quest completion.
- Keep encounters spaced and quiet enough for the player to notice them. Avoid repeatedly spawning deer, rabbits or patrols around the camera. These two authored animal encounters establish life; they need not imply a finished world population system.

## 2. A Friend in Trouble

Existing ID: `a_friend_in_trouble`.

### Approach and rescue

The woods swallow the sound of the marsh. Close to the rescue site, the player hears a cup strike a stone and a guard complain about having to wait for the captain. Through the brush, Nib sits against a tree with one ankle swollen and his hands bound in front of him. Their stolen basket lies beside the guards' supplies.

The guards are members of a local goblin raiding band. Their acts establish their hostility; do not imply that all goblins raid, or accidentally identify them as the neutral adventurers.

Nib notices the player first. He looks toward a second guard rather than calling out and exposing the approach. Keep this readable in a simple head turn or short line if a bespoke animation is unavailable.

The existing rescue requires defeating the marked guards. Stealth, distraction and negotiated rescue are future possibilities, not promised branches in this version. Allow ordinary combat approaches and positioning without forcing the player into a cutscene ambush.

### After the fight

The protagonist cuts the binding. Nib reaches for the basket before trying to stand.

> **Protagonist:** “Leave it.”
>
> **Nib:** “There's dry tinder underneath.”
>
> **Protagonist:** “You nearly died for tinder?”
>
> **Nib:** “And the pot. You burn everything without a pot.”

The humour should sound tired and familiar. Nib's hands shake while he checks the contents; give the moment room before the next objective.

> **Nib:** “I thought you'd gone downriver.”
>
> **Protagonist:** “I heard them bring you through.”
>
> **Nib:** “You should have kept going.”
>
> **Protagonist:** “Can you walk?”

Nib admits he can manage slowly. He describes a cave he saw while gathering above the northeastern paths: a dry entrance, a stream nearby, and old stonework inside. He did not enter because he heard something heavy moving in the clearing.

> **Nib:** “Might be nothing.”
>
> **Protagonist:** “How heavy?”
>
> **Nib:** “Heavy enough that I left the mushrooms.”

### Travel staging

Nib takes a sheltered route after resting; the player scouts and gathers supplies. Use the existing transition from rescue site to home location. An offscreen relocation after dialogue is acceptable. Do not imply a working escort AI, expose an invulnerable Nib to repeated combat or add escort failure states for this draft.

Before the hearth is safe, stage Nib in a narrow sheltered recess the ogre cannot reach, or explain that he waits on the approach. He must not casually occupy the ogre's feeding ground.

## 3. A Place to Belong

Existing ID: `a_place_to_belong`.

### Discovering the cave

The cave entrance catches the last daylight. Beneath the damp smell of the outer rock, the interior is dry. A shallow firepit sits behind a low stone lip. Along the wall, someone has scratched rows of short marks and a small picture of a flame.

Nib runs his thumb across one of the marks.

> **Nib:** “Someone counted the nights.”
>
> **Protagonist:** “How many?”
>
> **Nib:** “More than we've managed.”

Neither knows who lived here or why they left. Do not immediately label it an ancient goblin kingdom. The cave's history should survive beyond one chapter.

### The three supplies

Retain the existing mushroom basket, firewood bundle and old blanket pickups and their current locations unless world work requires adjustment. Dress those locations to tell these stories rather than moving them to imaginary landmarks.

| Pickup | Environmental detail | Meaning at the hearth |
|---|---|---|
| Mushroom basket | A collapsed gathering shelter or scattered wicker; Nib identifies which mushrooms can be cooked safely. | Food for tonight, with a little left for morning. |
| Firewood bundle | Someone stacked split wood under stone or a fallen beam. The outer pieces are soaked; the centre remains dry. | The player deliberately brings the fuel that makes the ending possible. |
| Old blanket | A deserted bedroll at the ruins, with an old stitched repair and no body or active owner nearby. | Nib can finally sleep without shivering. |

Use short inspection text or contextual dialogue. Do not add hunger, crafting, inventory puzzles or a mushroom-identification minigame as prerequisites.

### The adventurer camp

An optional encounter uses the existing three camp adventurers. A watchful fighter keeps a hand near a weapon; another notices the goblin's empty hands or battered knife. They remain neutral unless the game's existing faction rules justify defence.

> **Camp lookout:** “Stay where we can see you.”
>
> **Protagonist:** “Something lives by the northern cave.”
>
> **Camp lookout:** “An ogre. We heard it breaking trees.”
>
> **Another adventurer:** “Keep clear of the hollow. It can move faster than it looks.”

They need not become friends or give equipment. Their warning supplies useful information, and permitting the player to leave establishes restraint. Do not require this conversation for the main quest or spawn a fourth healer.

### The ruined shrine

The Stone Guard shrine is an optional discovery using the existing ability interaction. Its carving shows several worn figures beneath interlocking hands. The faces have weathered away; their species is uncertain.

When the player touches the rune, loose grit lifts from the stone. Pressure gathers across the shoulders and forearms, then releases. A blow that might have split the carving has left it cracked but standing.

Inspection text: “The hands are worn smooth. The hollow beneath them is sheltered from the rain.”

Ability notification: “Stone Guard acquired.” Keep the mechanical explanation separate and brief. No disembodied lecturer, required lore speech or claim that every visitor could activate the shrine. Why it answers this protagonist remains a question.

### Other optional encounters

- **Alpha wolf:** use the established den and Wolf Dash essence. Gnawed remains and overlapping tracks warn of its territory. The encounter offers another way to prepare; it is not revenge for an invented wolf attack on Nib.
- **Raider captain:** use the established outpost and Flame Burst essence. A familiar basket weave or stolen cooking implement links the band to the burned shelter. The captain is an optional continuation of that threat, not a secretly required second chapter boss.
- **Clearwater Spring:** Nib or an adventurer may mention clean water. Retain the existing intended healing/cooldown design; do not turn ordinary ponds into universal healing stations.
- **Stillmere and Sunken Marsh:** optional paths provide silence, mist, waterlogged posts and signs of a road disappearing beneath mud. These are exploration details, not additional main quests.

Optional essence pickups must remain optional for defeating the ogre. No peaceful kills, arbitrary kill quota or mandatory grind should gate the home ending.

## 4. The Ogre's Claim

Existing ID: `the_ogres_claim`.

### Establishing the threat

The player sees broad footprints filling with water, bark stripped from a tree at shoulder height above them, and a stone dragged across a path. A distant impact interrupts birdsong or the ambient forest bed. These clues occur before the boss boundary.

The ogre uses the clearing to feed and rest. It is a territorial danger, with no connection to a cosmic villain required. It is not guarding a legendary weapon for the player.

From the shelter, Nib watches the player examine the clearing.

> **Nib:** “There's another valley.”
>
> **Protagonist:** “Can you reach it?”
>
> **Nib:** “Tomorrow. Maybe.”

The protagonist looks at the rain moving across the entrance and the dry floor behind them.

> **Protagonist:** “Get the tinder ready.”

Avoid presenting this as proof that killing is always the answer. These two injured travellers need immediate shelter, and the ogre's existing aggression makes the location unsafe. The player may leave and return better prepared.

### Fight and aftermath

Use the existing ogre, telegraphs, recovery windows and arena. Environmental staging should help read its reach and movement without adding scripted instant kills, a collapsing ceiling or a companion rescue mechanic.

When it falls, let the combat music resolve and the ordinary water and wind return. The protagonist steadies himself. Nib calls once from shelter before coming out.

> **Nib:** “You're bleeding.”
>
> **Protagonist:** “A little.”
>
> **Nib:** “That's what you said about the roof.”

If wounds are not dynamically supported, avoid a mandatory blood animation or persistent injury system. The exchange can be adjusted to “You're shaking.” Preserve the exhaustion and Nib's concern.

The victory clears a threat; it does not heal the protagonist automatically or award the ogre's possessions as unexplained equipment.

## 5. A Fire of Our Own

Existing ID: `something_greater`; proposed displayed title: “A Fire of Our Own”.

### Claiming the hearth

Return to the existing cave hearth. The three gathered supplies should become visible through simple prop states: basket beside the wall, folded blanket on a dry patch, a smaller wood stack near the pit. Nib clears ash while the protagonist lays the fuel. A simple interaction and fade are sufficient if custom animation is unavailable.

The first attempt produces smoke. Nib shields the ember with both hands.

> **Nib:** “Slowly. Let it breathe.”

A flame catches along the smallest split stick. The protagonist feeds it another.

> **Nib:** “Think it'll hold?”
>
> **Protagonist:** “The roof?”
>
> **Nib:** “Us.”

The protagonist sets the knife within reach and sits.

> **Protagonist:** “I'll take first watch.”

Nib divides the food into two portions. His is smaller. The protagonist notices and pushes part of his own back across the stone. Neither comments.

This action completes the emotional arc: they have food, a dry place to sleep, and someone who will remain awake for the other.

### Night and closing image

Later, Nib sleeps beneath the blanket. The protagonist turns a coal with a stick. In the changing firelight, the old wall marks seem deeper than before.

A faint vibration passes through the hearth stone. The goblin stills. Beneath the ash, a thin line glows, then another: part of a pattern hidden by soot. For a moment, he feels the pulse in his wrist answer it.

He pulls his hand away. The glow fades.

> **Nib, half asleep:** “Fire going out?”
>
> **Protagonist:** “No. Sleep.”

Outside, rain falls steadily into the empty clearing.

End on the tended fire and the two figures inside its light. Show “Chapter 1 complete” after the scene, with the home checkpoint active. Avoid a sudden enemy reveal that steals this moment of safety.

### What the ending establishes

- The cave is the first home, not a finished settlement or an invulnerable fortress.
- The protagonist has encountered power that can be learned or absorbed. The hearth suggests a deeper relationship without explaining it yet.
- Nib has contributed shelter knowledge, fire-making and practical care; he is more than a rescued quest marker.
- Chapter 2 can investigate the buried stonework and the protagonist's changing body. No named empire, deity, princess or final antagonist is fixed by this chapter.

## Implementation checklist for Claude

### First pass: story using existing systems

- Read current `quest_data.gd`, `quest_world.gd`, `quest_friend.gd`, progression and chapter-completion listeners before editing.
- Replace placeholder summaries, objective text and dialogue with the scene content above, shortened where necessary for the existing notification UI. Do not dump long exchanges into overlapping timed toasts; use staged interactions or a small readable dialogue presentation.
- Retain stable quest IDs. Keep rescue guard credit restricted to the existing marked enemies and preserve faction, LOS and fair-combat rules.
- Add scarf/basket clues, wall scratches and supply dressing using existing or procedural assets. Check real terrain placement, navigation and camera visibility.
- Provide Nib dialogue states for injured, rescued, waiting for a safe cave and settled at home. Optional lines should not replay every frame or block combat.
- Reconcile the proposed ending: home claimed after ogre defeat completes Chapter 1; level 5 and Hobgoblin transformation move to later progression. Audit signals, achievements if present, save flags and reload behaviour rather than simply deleting the last two quest steps.
- Existing completed saves must not lose evolution, rewards or completion. Decide and document how saves partway through the old final quest resume; never duplicate XP or home rewards.
- Make core scenes work if the player already collected supplies, defeated optional enemies, defeated the ogre early, or skipped the camp and shrine. Respect the actual quest event/persistence system rather than assuming it remembers earlier actions.
- Let the player resume control after the ending. Keep the full-game launch arrangement unchanged unless separately assigned.

### Second pass: presentation

- Implement and visibly review the requested rabbit, deer and adventurer search encounters above. They are additions to the earlier wildlife-deferred scope. Add animal models/behaviours only as needed for these encounters, and report anything still missing.
- Add the two searchable wolf carcasses and the abandoned Battered Short Sword. Verify each pickup once, save/reload persistence, inventory/equip/stow, sword-specific reach and animations, and continued access to the knife. Scavenging these existing deaths must not grant player kill credit. All pickups are optional for rescuing Nib.
- Verify the hiding route against actual adventurer detection and collision. Test both unnoticed passage and discovery, plus patrol-to-camp continuity and save/load. Atmosphere alone is not proof of a working avoidance encounter.
- Add restrained sound and camera staging: wet glade, muffled rescue-site conversation, distant ogre impacts, quiet after victory, close hearth crackle.
- Render the closing rune with a small light/material state; it needs no new magic subsystem or evolution animation.
- Optional exploration dialogue can wait until the five required scenes are readable and complete.

### Verification

- Play the full sequence from a new game: glade → rescue → cave/supplies → ogre → hearth → completion.
- Check save/load before and after rescue, supply collection, ogre defeat and hearth claiming; conversations and rewards must not duplicate.
- Check early exploration and optional-content skips. A player with only the starting kit must have a viable route through the required encounters.
- Confirm Nib appears in a sensible safe position, objectives point to the correct locations, dialogue stays readable and optional scenes do not interrupt active combat.
- Report what was implemented, what remains a writing specification, and any difference from this draft. Automated checks do not replace a visible playthrough of the ending.
