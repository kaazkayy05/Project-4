"""PURGATORY Act 1 — native Blender scene builder, 10 editable scenes.

HOW TO USE:
1. Extract the complete starter ZIP to a writable folder.
2. Blender > Scripting > Open this file > Run Script (Alt+P).
3. File saves: purgatory_act1_greybox.blend alongside this script.

This script relies ONLY on Blender's built-in bpy, json, math, pathlib.
It does not implement gameplay, collisions or automatic level-loading logic.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

# Set this manually if Blender cannot locate the extracted pack.
PACK_ROOT_OVERRIDE = ''
SAVE_BLEND = True
MAKE_LABELS = True

if PACK_ROOT_OVERRIDE:
    ROOT = Path(PACK_ROOT_OVERRIDE).expanduser().resolve()
else:
    try:
        ROOT = Path(__file__).resolve().parent
    except NameError:
        ROOT = Path(bpy.path.abspath('//')).resolve()

MANIFEST = ROOT / 'act1_manifest.json'
if not MANIFEST.exists():
    raise FileNotFoundError(
        f'Could not find {MANIFEST}. Extract the ENTIRE ZIP, open this script '
        'inside Blender, or set PACK_ROOT_OVERRIDE to the extracted folder.'
    )
with MANIFEST.open(encoding='utf8') as stream:
    data = json.load(stream)

# Keep a temporary scene alive while replacing Blender's startup scenes.
bootstrap = bpy.data.scenes.new('ACT1_TEMP_SETUP')
bpy.context.window.scene = bootstrap
for old_scene in list(bpy.data.scenes):
    if old_scene != bootstrap:
        bpy.data.scenes.remove(old_scene)

scene_objects = {}
for index, level in enumerate(data['levels']):
    sid = level['id']
    sc = bpy.data.scenes.new(f"{level['number']:02d} — {level['theme']}")
    bpy.context.window.scene = sc
    sc['level_id'] = sid
    sc['level_number'] = level['number']
    sc['theme'] = level['theme']
    sc['layout'] = level['layout']
    sc['introduced_ability'] = level['introduced_ability'] or 'NONE'
    sc['available_abilities'] = ', '.join(level['abilities'])
    sc['story_note'] = level['story_note']
    sc['karma_threshold_status'] = 'UNASSIGNED — set from character life events'
    sc['next_level_id'] = f"level_{level['number']+1:02d}" if level['number'] < 10 else 'ACT_1_END'
    sc['is_proposed_layout'] = bool(level['proposed_layout'])
    sc['no_level_selection_or_replay'] = True

    # Individual scenes make sense in Blender but do not imply a level-select UI.
    main_cols={}
    for category in ('01_WALKABLE', '02_SOLID_BARRIERS', '03_MECHANIC_CUES',
                     '04_THEME_BLOCKOUT', '05_STORY_AND_KARMA', '06_SPAWN_EXIT',
                     '07_DESIGN_LABELS', '08_CAMERA_AND_LIGHTS'):
        c = bpy.data.collections.new(category+'__'+sid)
        sc.collection.children.link(c)
        main_cols[category] = c

    path = ROOT / 'levels' / level['glb']
    if not path.exists():
        raise FileNotFoundError('Missing GLB file: '+str(path))
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = list(sc.objects)
    role_map={o['name']:o for o in level['geometry']}

    def category_for(role, name):
        if role == 'WALKABLE': return '01_WALKABLE'
        if role in ('SOLID','WALLRUN'):
            return '03_MECHANIC_CUES' if role == 'WALLRUN' else '02_SOLID_BARRIERS'
        if role in ('GUIDE',): return '03_MECHANIC_CUES'
        if role in ('PICKUP','KARMA_PICKUP'): return '05_STORY_AND_KARMA'
        if role in ('SPAWN','EXIT'): return '06_SPAWN_EXIT'
        return '04_THEME_BLOCKOUT'

    # Blender may add .001 to duplicate names across scenes.
    for ob in imported:
        original_name = ob.name
        base = original_name.rsplit('.',1)[0] if original_name.rsplit('.',1)[-1].isdigit() else original_name
        spec = role_map.get(original_name, role_map.get(base))
        role = spec['role'] if spec else 'DECOR'
        ob['greybox_role']=role
        if spec:
            ob['level_id']=sid
            ob['greybox_material']=spec['material']
            if role=='WALLRUN': ob['intended_surface']='WALL RUN / needs engine collision'
            if role in ('PICKUP','KARMA_PICKUP'): ob['collectible_placeholder']=True
            if role=='EXIT': ob['engine_event']='LEVEL_COMPLETED'
            if role=='SPAWN': ob['engine_event']='LEVEL_SPAWN'
        dest=main_cols[category_for(role,original_name)]
        if ob.name not in dest.objects: dest.objects.link(ob)
        for c in list(ob.users_collection):
            if c != dest:
                c.objects.unlink(ob)

    # Scene-specific reference labels (visible in Blender, safe to delete).
    if MAKE_LABELS:
        for j,record in enumerate(level['notes']):
            txt = bpy.data.curves.new('Text Guide','FONT')
            txt.body=record['text']
            txt.size=1.8 if len(txt.body)<=25 else 1.35
            txt.extrude=0.01
            obj=bpy.data.objects.new('GUIDE_TEXT_'+str(j).zfill(2),txt)
            obj.location=(record['point'][0]+1.2,record['point'][1]+1.1,7.6)
            main_cols['07_DESIGN_LABELS'].objects.link(obj)
            obj['greybox_role']='EDITOR_NOTE_ONLY'

    # Deterministic top-down camera with useful scale.
    walkable = [o for o in level['geometry'] if o['role']=='WALKABLE']
    minx=min(o['pos'][0]-o['size'][0]/2 for o in walkable)
    maxx=max(o['pos'][0]+o['size'][0]/2 for o in walkable)
    miny=min(o['pos'][1]-o['size'][1]/2 for o in walkable)
    maxy=max(o['pos'][1]+o['size'][1]/2 for o in walkable)
    cx,cy=(minx+maxx)/2,(miny+maxy)/2
    cam_data=bpy.data.cameras.new('Top-Down Design Camera')
    cam=bpy.data.objects.new('Top-Down Design Camera',cam_data)
    main_cols['08_CAMERA_AND_LIGHTS'].objects.link(cam)
    cam.location=(cx,cy,200)
    cam.rotation_euler=(0,0,0)
    cam_data.type='ORTHO'
    cam_data.ortho_scale=max((maxy-miny)*1.25,(maxx-minx)*1.04)
    sc.camera=cam
    sun_data=bpy.data.lights.new('Greybox Sun','SUN')
    sun=bpy.data.objects.new('Greybox Sun',sun_data)
    main_cols['08_CAMERA_AND_LIGHTS'].objects.link(sun)
    sun.location=(cx-15,cy+22,60)
    sun.rotation_euler=(math.radians(24),math.radians(-22),math.radians(-18))
    sun_data.energy=2.0
    sc.world=bpy.data.worlds.new('Greybox World '+sid)
    sc.world.use_nodes=True
    sc.world.node_tree.nodes['Background'].inputs['Color'].default_value=(0.15,0.18,0.24,1.0)
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value=0.65
    for engine in ('BLENDER_EEVEE_NEXT','BLENDER_EEVEE','BLENDER_WORKBENCH'):
        try:
            sc.render.engine=engine
            break
        except Exception:
            continue
    sc.render.resolution_x=1400;sc.render.resolution_y=1000
    sc.render.resolution_percentage=100
    try:
        sc.view_settings.view_transform='AgX'
    except Exception:
        sc.view_settings.view_transform='Standard'
    scene_objects[sid]=sc

# Return to Level 1; no in-game scene selection is created by the project.
bpy.context.window.scene=scene_objects['level_01']
bpy.data.scenes.remove(bootstrap)
if SAVE_BLEND:
    output=ROOT/'purgatory_act1_greybox.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    print('Created',output)
print('Built',len(scene_objects),'sequential ACT 1 Blender scenes.')
print('These are 3D BLOCKOUTS ONLY; gameplay progression and abilities need implementation in the game engine.')
