# Purgatory — Act 1: Route Greyboxing in Blender

This is an **editable 3D LEVEL-DESIGN STARTER KIT** for the ten specified Act 1 levels. It is not a playable game, and it does not implement Dash, Wall Run, Scream Jump, Karma, or level loading. The map layout is ready to inspect and edit; all ability ranges and heights are provisional and must be tested against your character controller.

## Files included

- `build_act1_in_blender.py` — uses Blender's built-in Python to import the ten GLB levels, sort them into collections, add labels/cameras, and save `purgatory_act1_greybox.blend`.
- `levels/*.glb` — ten stand-alone editable 3D levels. You can import any of these directly into Blender without running the building script.
- `plans/level_01_plan.png` through `level_10_plan.png` — top-down route diagrams.
- `act1_overview.png` — planning overview; **not** a level select UI.
- `act1_manifest.json` — object names, positions, gameplay-design roles, route markers, current layouts and unlock schedule.
- `generate_act1.py` — optional standalone Python generator that regenerates the GLB and plan PNG files with `numpy trimesh matplotlib`; it does not run inside Blender.

## Open the complete project in Blender

1. Extract the **entire ZIP** into a folder you can write to. Keep `levels/`, `act1_manifest.json` and `build_act1_in_blender.py` together.
2. Open Blender > **General**. Select the **Scripting** workspace along the top.
3. In the Text Editor, choose **Open** and browse to the extracted `build_act1_in_blender.py`.
4. Click **Run Script** at the top of the Text Editor, or move your pointer over the Text Editor and press **Alt+P**.
5. When finished, Blender will save **`purgatory_act1_greybox.blend`** beside the script. The active scene opens Level 1.
6. To inspect other levels, open the **Scene** selector near the upper right (beside View Layer). You get one editable Blender scene per level. **This is an editor-only convenience, not a game menu.**

**If the script reports it can't find `act1_manifest.json`:** Edit `PACK_ROOT_OVERRIDE` at the top of `build_act1_in_blender.py` to the full directory holding the extracted files, e.g. `r'C:\Users\You\Downloads\purgatory_act1_greybox'`, then run again. Do not point it at the ZIP itself.

**Simpler alternative:** File > Import > glTF 2.0 (.glb/.gltf) > `levels/level_01_christmas.glb`. This imports one 3D level into your current Blender scene but won't automatically create all ten scenes and labels.

## Legend

| Color | Purpose |
|---|---|
| Light grey | Walkable floor / basic platform |
| Dark blue-grey | Walls, geometry, obstacles |
| Cyan | Dash cue |
| Purple | Scream Jump cue |
| Gold wall | Wall Run surface |
| Yellow orb / candy | Karma pickup placeholder; no score assigned |
| Purple diamond | Story Item placeholder |
| Green disc | Player spawn |
| Blue disc / arch | Exit trigger placeholder |
| Dark red far below | Debug fall zone; **not** a working kill volume |

Themed objects (trees, gift boxes, donation racks, pumpkins, bleachers, graves, dance tables, etc.) are purposefully made of simple shapes. They are indicators of intended atmosphere, not art assets.

## Build a simple level yourself — Level 1, Christmas

Start with a new Blender file and practice recreating the Level 1 greybox instead of immediately modifying all ten levels. Coordinates below match the included GLB (X = left/right, Y = forward, Z = up; dimensions approximate).

### A. Make a starting floor

1. Press `Shift+A > Mesh > Cube`.
2. Press `N` (sidebar) > **Item**.
3. Under **Transform**, enter `Location X=0, Y=7, Z=-0.35`.
4. Under **Dimensions**, enter `X=18, Y=14, Z=0.7`.
5. In **Object Mode**, press `Ctrl+A > Scale` to bake the scale into mesh dimensions.
6. Rename the object `L01_START_FLOOR` using `F2`.

The floor surface is now at Z=0. Don't spend time on textures.

### B. Add the main Dash gap and landing floor

1. Duplicate your first floor using `Shift+D`, or add a second cube.
2. Set landing `Location (0, 28.5, -0.35)` and `Dimensions (16, 19, 0.7)`.
3. This leaves a **5-unit empty span** from the end of the start platform at Y=14 to the next at Y=19.
4. Name it `L01_DASH_LANDING`. Use an unobtrusive cyan cube at the edge as a visual Dash cue.
5. Press `Numpad 7` to check the gap in top view; `Numpad 1` to check the jump height from the side.

If your character's Dash only travels 4 units, this gap is too long. If it travels 12, the gap is too easy. **Calibrate it in the game engine**, then adjust the cubes in Blender.

### C. Add the exit area and one obstacle

1. Add a floor cube at `Location (0, 48.5, -0.35)` with `Dimensions (14, 21, 0.7)`. This adjoins the landing floor.
2. Add a grey cube around `(0,30,0.7)`, dimensions `(5,1.2,1.4)` as a low gift-like obstacle. It should encourage moving around or over it without creating an alternate route.
3. Add a green cylinder at `(0,4,0.1)` for player spawn and a blue cylinder at `(0,55,0.12)` for the end trigger marker.
4. Model a Christmas tree using a cylinder for its trunk and one or more cone primitives. Copy these to the sides of the route, rather than into critical collision spaces.
5. Add a purple story-item sphere/diamond on the main floor and yellow Karma markers. These are visual markers only.

### D. Organize the level so it is editable

In the **Outliner** (top right), right-click > **New Collection** and use:

- `GEO_WALKABLE` for platforms and floors.
- `COLLISION_BLOCKOUT` for obstacle placeholders.
- `THEME_BLOCKOUT` for Christmas props.
- `MECHANIC_CUES` for bright markers indicating ability use.
- `STORY_KARMA` for pick-up placeholders.
- `SPAWN_EXIT` for the starting and ending markers.

Select objects and press **M** to move them into a collection. You can toggle collections on and off in the Outliner.

### E. Test as a game route

1. Position a 1.8-unit-tall capsule to represent the player.
2. Compare the required jump, Dash and Scream Jump distances to your actual game movement values. We have not set these values for your project, so this kit does not pretend to have validated them.
3. Make sure the next destination is clear from the expected first-person/third-person camera height.
4. Make sure the player can't bypass the intended Dash gap by walking along a prop, a beam, or an unintended corner.
5. Keep the Story Item visible, but do not add a compulsory secret path where your design says only one route exists.
6. When the geometry works, apply collision meshes and movement logic in your game engine, not in Blender alone.

## Level-specific design intent

### L1 — Christmas (linear)
A single route. A deliberate Dash gap introduces Dash, which is available from the start. Present/gift blockouts and trees suggest Christmas without decorating prematurely.

### L2 — Donating clothes at Goodwill (main + dead end)
One main corridor with two simple Dash interruptions. A clearly *non-progressing* side corridor leads to the clothes collection room and optional Story Item. The exit remains on the original main route.

### L3 — Halloween (linear forward detour, exit behind)
The character starts facing forward. The exit is behind the spawn and visible across a much-too-large missing floor segment, so the player must travel forward along the long path that curves around to it. The critical route never splits; candy-shaped markers indicate Karma pickups. Confirm the forbidden gap is beyond all movement ability ranges currently unlocked, including combinations or edge exploits.

### L4 — Football (three routes, unlock Scream Jump)
The spawn is in the locker room, followed by the tunnel. A stadium entrance splits into **left stands / field / right stands** routes, which meet near the far end zone. Use rising tiers to introduce Scream Jump. Each branch should be traversable with Dash and Scream Jump alone.

### L5 — Grim funeral (maze)
The entrance feeds a rectangular cemetery maze with walls defining corridors, wrong turns and a Story Item in a side corridor. A funeral chapel forms the exit space. This is intentionally denser than earlier levels.

### L6 — Football revisited (three routes, unlock Wall Run)
A similar locker room and three-route stadium structure is used again. The middle section now has longer gaps and marked wall-running surfaces. Wall Run should be *necessary*, not just decorative, once the movement is tuned. The repeated location can later communicate how memory changes.

### L7 — Valentine's Day (provisional)
Two romantic park paths reconnect at a central plaza. A short garden detour contains a Story Item. The outline uses more vertical traversal and Wall Run / Scream Jump, but the exact story event is deliberately undecided.

### L8 — School dance (provisional)
The foyer leads to a main dance floor, with balcony paths running around its edges. A cloakroom detour holds an optional Story Item. The balcony changes height; varied movement is more important than precise decoration.

### L9 — College admission (provisional)
Multiple campus wings, interconnecting routes and an elevated admissions hall. The map is spatially complicated, allowing multiple viable ways through the memory. The narrative outcome (acceptance, rejection, relationships) is not assumed by the blockout.

### L10 — Heartbroken (visually hectic, geometrically simpler)
Return to one main path using fewer platforms, but force advanced, fast combinations of Dash, Wall Run, and Scream Jump. Floating false doors and shards suggest confusing memories but are intentionally tagged as decorative, non-walkable geometry. The finish marker ends Act 1. It is not a level-replay menu.

## Ability progression (hard constraint)

- **Level 1 start:** Dash unlocked. Available for all levels.
- **Level 4 start:** Scream Jump unlocked. Available in Levels 4–10.
- **Level 6 start:** Wall Run unlocked. Available in Levels 6–10.
- All exits auto-progress to the *next* level in the eventual game, and Level 10 completes Act 1. There is **no in-game level selection or replay**.

## What this starter kit does not do

No game-engine code is included. The colored surfaces and trigger discs **do not** implement collisions, physics, kill volumes, collectible logic, Karma thresholds, level loading, checkpoint saving, or cinematics. The final character controller and camera must determine actual route spacing. Scene count and scene selection in Blender are an editing feature only.

## Editing layouts efficiently

- **Move a platform:** select it > `G` (and `X`, `Y`, or `Z` to constrain).
- **Resize a platform:** `S` (and axis), or type exact Dimensions in `N > Item`; `Ctrl+A > Scale` afterward.
- **Make a branch:** duplicate a platform `Shift+D`, offset it sideways, and build a connector (bridge, dash gap, or step) where the branch should begin.
- **Make a maze:** use a shared floor, and lay out box walls on a grid. Test that you can actually reach the exit before adding traps.
- **Make a wall-run section:** position a tall wall parallel to the travel direction with takeoff and landing platforms on either end. Keep the wall uninterrupted across the gap.
- **Test route clarity:** toggle top view with `Numpad 7` and orbit into third-person perspective with middle mouse. Ensure the route is readable from the ground, not only the overview.
- **Save versions:** `File > Save As`, e.g. `act1_greybox_v02.blend` before large revisions.

This is Step 2 in a level-design workflow: route blockout now, mechanics and movement-scale validation next, environment art only after the routes work.
