ANIMATED ZOMBIE HANDS & FOUR DIFFERENT GRAVESTONES
==================================================

WHAT YOU GET
------------
Zombie_Graves_Animated.glb
  Fully modeled 3D graveyard for direct Blender import; 4 different
  gravestones, 5 zombie hands, soil, rocks, roots, and rising animation.
  The GLB has 5 animated parent objects and a 6-second action.

Create_Animated_Zombie_Graves.py + geometry.py
  Blender Python builder for the original procedural geometry PLUS
  more advanced materials, stone bevels, lighting, a cinematic camera,
  animated dirt debris, and 180 frames of keyframes.
  Running this script SAVES Zombie_Graves_Animated.blend on your computer.

Geometry_Preview_Actual_Mesh.png
Hands_Emerging_Geometry_Preview.gif
  The preview uses exactly the SAME vertex meshes as the Blender builder,
  rendered in a separate preview renderer (NOT a Blender screenshot).
  Blender Cycles rendering differs in lighting, bevel, shader grain,
  and shadows; shapes/layout are from the same geometry.

IMPORT THE ANIMATED 3D MODEL DIRECTLY
-------------------------------------
1. Launch Blender 4.x or later.
2. File > Import > glTF 2.0 (.glb/.gltf).
3. Select Zombie_Graves_Animated.glb.
4. Press SPACE to play the animation. On imported glTF files Blender's
   scene duration may need setting to frames 1 through 180 at 30fps.
5. Set the scene frame to ~154 to see all hands above ground.
6. Save As .blend when done.

BUILD A FULL BLENDER SCENE WITH LIGHTING AND SOIL ANIMATION
-----------------------------------------------------------
1. Extract this ZIP so Create_Animated_Zombie_Graves.py and geometry.py
   are side by side in the same folder.
2. Open Blender > Scripting > Text Editor > Open.
3. Open Create_Animated_Zombie_Graves.py.
4. Click Run Script (ALT+P).
5. Script generates all models, lights, camera, and soil debris animation.
6. It automatically saves Zombie_Graves_Animated.blend into the same folder.
7. Use frame 154 and F12 to render the final pose; press SPACE to animate.
8. Ctrl+F12 renders all 180 frames; configure video export first.

TIMING (30 FPS)
---------------
Frames 1–180 = 6 seconds. The 5 hands start rising at staggered intervals,
then settle into their final clawing poses. All 4 gravestones are static.

MODEL DETAILS
-------------
1. Celtic cross with ancient circular stone ring and cracked cross stem
2. Rounded Victorian slab with 3D R.I.P. lettering
3. Gothic pointed slab with stone crucifix
4. Tapered obelisk with weathered cracks
5. Five greenish elongated clawed zombie hands, each with all five fingers,
   jagged claws, ragged sleeve cuffs, and individual rising keyframes
6. Tilled soil and earth debris around hand emergence sites

IMPORTANT
---------
The preview is generated from actual 3D mesh vertices, not a painted
concept image. However, Blender was not installed in this workspace, so
this pack does NOT include a pre-rendered Blender screenshot or pre-built
.blend file. The builder script creates and saves a .blend when you run
it in Blender. The directly-importable .glb already includes the animation.
