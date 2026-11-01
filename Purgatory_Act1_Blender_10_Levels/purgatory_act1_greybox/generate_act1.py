"""Generate editable GLB greyboxes and level plans for a sequential Purgatory Act 1.
Dependencies (for regeneration only): numpy, trimesh, matplotlib.
The GLB files import natively into Blender; the included Blender script constructs .blend scenes.
All dimensions are provisional greybox dimensions and should be tuned to gameplay.
"""
from __future__ import annotations
import json, math, random, zipfile
from collections import defaultdict
from pathlib import Path
import numpy as np
import trimesh
from matplotlib import pyplot as plt
from matplotlib.patches import Rectangle, Circle, Polygon, FancyArrowPatch

ROOT = Path(__file__).resolve().parent
LEVELS = ROOT/'levels'; PLANS = ROOT/'plans'
LEVELS.mkdir(exist_ok=True); PLANS.mkdir(exist_ok=True)
COLOR = dict(
    floor='#A4AFBD', raised='#C0CCD8', wall='#536273', ceiling='#87919E',
    dash='#38C2DC', scream='#B987E8', wallrun='#E5BC62', story='#D3A4F4',
    karma='#F0D05A', spawn='#62DCAE', exit='#68BBF4', void='#CA6267',
    prop='#73818D', decoration='#6C7186', xmas='#669B83', red='#BA777A',
    blue='#7C9DAF', orange='#DBA169', purple='#8D7DAE', football='#799788',
    dark='#65707B', rose='#A781A2', gold='#CAAB72', heartbreak='#BB6D83'
)
COL_RGB={k: tuple(int(v[i:i+2],16)/255 for i in (1,3,5)) for k,v in COLOR.items()}

class Level:
    def __init__(self, idx, name, theme, layout, unlock, abilities, story_note, proposed=False):
        self.n=idx; self.id=f'level_{idx:02d}';self.name=name;self.theme=theme;self.layout=layout
        self.unlock=unlock;self.abilities=abilities;self.story_note=story_note;self.proposed=proposed
        self.items=[];self.routes=[];self.notes=[];self.scene=trimesh.Scene();self._n=0
        self.spawn=(0.,4.,0.);self.exit=(0.,50.,0.);self.karma_required=None
    def add(self, primitive, name, x, y, z, w, d, h, mat='floor', role='SOLID', rot=0, **meta):
        # All positions are centers; public route/platform heights are *top* elevations.
        self._n+=1
        item=dict(name=f'{name}_{self._n:04d}', primitive=primitive, pos=[float(x),float(y),float(z)],
                  size=[float(w),float(d),float(h)], rot=float(rot), material=mat, role=role, **meta)
        self.items.append(item)
        if primitive=='BOX': mesh=trimesh.creation.box(extents=[w,d,h])
        elif primitive=='CYL': mesh=trimesh.creation.cylinder(radius=w/2,height=h,sections=16)
        elif primitive=='CONE': mesh=trimesh.creation.cone(radius=w/2,height=h,sections=12)
        elif primitive=='ICOSPHERE': mesh=trimesh.creation.icosphere(subdivisions=1,radius=0.5);mesh.apply_scale([w,d,h])
        else: raise ValueError(primitive)
        if rot:
            mesh.apply_transform(trimesh.transformations.rotation_matrix(math.radians(rot),(0,0,1)))
        mesh.apply_translation((x,y,z))
        mesh.visual=trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(
            name=mat, baseColorFactor=[*COL_RGB[mat],1.0], metallicFactor=0, roughnessFactor=.9,
            doubleSided=True))
        self.scene.add_geometry(mesh,node_name=item['name'],geom_name=item['name'])
        return item
    def cube(self,name,x,y,z,w,d,h,mat='floor',role='SOLID',rot=0,**kw):
        return self.add('BOX',name,x,y,z,w,d,h,mat,role,rot,**kw)
    def floor(self,name,x0,x1,y0,y1,top=0,mat='floor'):
        return self.cube(name,(x0+x1)/2,(y0+y1)/2,top-.35,x1-x0,y1-y0,.7,mat,'WALKABLE')
    def corridor(self,name,points,width=8,top=0,mat='floor'):
        for j,(a,b) in enumerate(zip(points,points[1:])):
            x0,y0=a;x1,y1=b
            length=math.hypot(x1-x0,y1-y0)
            rot=-math.degrees(math.atan2(x1-x0,y1-y0))
            self.cube(f'{name}_SEG{j+1}',(x0+x1)/2,(y0+y1)/2,top-.35,width,length+1.4,.7,mat,'WALKABLE',rot)
        # add junction pads for tight diagonal turns
        for j,(x,y) in enumerate(points[1:-1]):
            self.cube(f'{name}_TURN{j+1}',x,y,top-.35,width,width,.7,mat,'WALKABLE')
    def cylinder(self,name,x,y,z,r,h,mat='prop',role='DECOR'):
        return self.add('CYL',name,x,y,z,r*2,r*2,h,mat,role)
    def cone(self,name,x,y,z,r,h,mat='prop',role='DECOR'):
        return self.add('CONE',name,x,y,z,r*2,r*2,h,mat,role)
    def sphere(self,name,x,y,z,r,mat='decoration',role='DECOR'):
        return self.add('ICOSPHERE',name,x,y,z,r*2,r*2,r*2,mat,role)
    def diamond(self,name,x,y,z,r=.55,mat='story',role='PICKUP'):
        return self.add('ICOSPHERE',name,x,y,z,r*2,r*2,r*2,mat,role)
    def route(self,points,label='MAIN ROUTE',kind='MAIN'):
        self.routes.append(dict(label=label,kind=kind,points=[[float(x),float(y)] for x,y in points]))
    def note(self,text,x,y): self.notes.append(dict(text=text,point=[float(x),float(y)]))
    def dash_cue(self,x,y,top=0): self.cube('DASH_CUE',x,y,top+.06,3.2,.3,.12,'dash','GUIDE')
    def scream_cue(self,x,y,top=0): self.cylinder('SCREAM_JUMP_CUE',x,y,top+.07,.9,.14,'scream','GUIDE')
    def wallrun(self,x,y,length,top=0,height=5,axis='y'):
        if axis=='y': self.cube('WALL_RUN_SURFACE',x,y,top+height/2,.85,length,height,'wallrun','WALLRUN')
        else: self.cube('WALL_RUN_SURFACE',x,y,top+height/2,length,.85,height,'wallrun','WALLRUN')
    def void(self,x,y,w,d): self.cube('VOID_DEBUG_NONCOLLIDING',x,y,-3.1,w,d,.12,'void','GUIDE')
    def story(self,x,y,top=0,note='Unassigned story fragment'):
        self.cube('STORY_ITEM_PEDESTAL',x,y,top+.2,1.4,1.4,.4,'decoration','SOLID')
        self.diamond('STORY_ITEM_PICKUP',x,y,top+1.5,.7,'story','PICKUP')
        self.note('STORY ITEM: '+note,x,y)
    def karma(self,x,y,top=0,style='orb'):
        if style=='candy':
            self.cylinder('CANDY_KARMA_PICKUP',x,y,top+.75,.57,.5,'karma','KARMA_PICKUP')
            self.cone('WRAPPER_LEFT',x-.75,y,top+.75,.35,.5,'orange','DECOR')
            self.cone('WRAPPER_RIGHT',x+.75,y,top+.75,.35,.5,'orange','DECOR')
        else: self.sphere('KARMA_PICKUP',x,y,top+.95,.52,'karma','KARMA_PICKUP')
    def entry_exit(self):
        sx,sy,sz=self.spawn;ex,ey,ez=self.exit
        self.cylinder('PLAYER_SPAWN',sx,sy,sz+.1,1.25,.2,'spawn','SPAWN')
        self.cylinder('LEVEL_COMPLETION_TRIGGER_PLACEHOLDER',ex,ey,ez+.12,1.6,.25,'exit','EXIT')
        self.cylinder('EXIT_ARCH_L',ex-3.3,ey,ez+2.5,.4,5,'wall','GUIDE')
        self.cylinder('EXIT_ARCH_R',ex+3.3,ey,ez+2.5,.4,5,'wall','GUIDE')
        self.cube('EXIT_ARCH_HEADER',ex,ey,ez+5,7,.9,.65,'exit','GUIDE')
        self.note('START',sx,sy);self.note('END ACT 1' if self.n==10 else 'NEXT LEVEL',ex,ey)
    def export(self):
        p=LEVELS/f'{self.id}_{slug(self.theme)}.glb'
        p.write_bytes(self.scene.export(file_type='glb'))
        self.file=p.name
        return p
    def manifest(self):
        return dict(id=self.id,number=self.n,name=self.name,theme=self.theme,layout=self.layout,
                    introduced_ability=(self.unlock if self.unlock!='none' else None),abilities=self.abilities, proposed_layout=self.proposed,
                    story_note=self.story_note,karma_required=self.karma_required,
                    karma_rule='Narrative-specific threshold intentionally unspecified',
                    progression='Load next chronological level immediately; no level select or replay UI.',
                    spawn=self.spawn,exit=self.exit,glb=self.file,geometry=self.items,routes=self.routes,notes=self.notes)

def slug(t):return ''.join(x if x.isalnum() else '_' for x in t.lower()).strip('_')[:25]

def xmas_tree(l,x,y,scale=1):
    l.cylinder('TREE_TRUNK',x,y,.7*scale,.35*scale,1.4*scale,'prop')
    for h,r,z in ((2.7,1.6,2.0),(2.3,1.25,3.1),(1.9,.8,4.1)):
        l.cone('CHRISTMAS_TREE_BLOCKOUT',x,y,z*scale,r*scale,h*scale,'xmas')
    l.sphere('TREE_STAR_PLACEHOLDER',x,y,5.3*scale,.28*scale,'karma')

def gift(l,x,y,scale=1):
    l.cube('CHRISTMAS_GIFT',x,y,.55*scale,1.3*scale,1.3*scale,1.1*scale,'red')
    l.cube('GIFT_RIBBON',x,y,1.125*scale,.2*scale,1.38*scale,.1*scale,'gold')

def rack(l,x,y):
    l.cube('CLOTHING_RACK_RAIL',x,y,2.3,5,.3,.25,'blue')
    for dx in (-2.3,2.3):l.cube('RACK_LEG',x+dx,y,1.15,.28,.3,2.3,'prop')
    for dx in (-1.7,-.6,.5,1.6):l.cube('DONATED_SHIRT_PLACEHOLDER',x+dx,y,1.6,.83,.25,1.1,'decoration')

def pumpkin(l,x,y,scale=1):
    l.sphere('PUMPKIN_BLOCKOUT',x,y,.75*scale,.75*scale,'orange')
    l.cube('STEM',x,y,1.48*scale,.2*scale,.2*scale,.45*scale,'xmas')

def bleachers(l,x0,x1,y0,y1,z0=0,side='left'):
    for j in range(3):
        # terraces stay outside the playable stands route to avoid blocking passage
        xx=(x0+x1)/2+(-5-j*2 if side=='left' else 5+j*2)
        l.cube('BLEACHERS_STEP',xx,(y0+y1)/2,z0+.4+j*.6,2,y1-y0,.8+j*1.2,'prop','DECOR')

def goalpost(l,y):
    l.cylinder('GOALPOST_STEM',0,y,2.6,.3,5.2,'gold')
    l.cube('GOALPOST_BAR',0,y,5.4,8,.35,.3,'gold')
    for x in (-4,4):l.cube('GOALPOST_UPRIGHT',x,y,7,.3,.3,3.4,'gold')

def grave(l,x,y):
    l.cube('GRAVESTONE',x,y,1.1,1.2,.45,2.2,'dark','DECOR')

def heart(l,x,y,scale=1):
    l.sphere('HEART_LEFT_LOBE',x-.45*scale,y,1.7*scale,.7*scale,'rose')
    l.sphere('HEART_RIGHT_LOBE',x+.45*scale,y,1.7*scale,.7*scale,'rose')
    l.cube('HEART_TIP_BLOCKOUT',x,y,1.15*scale,1.35*scale,.7*scale,1.2*scale,'rose','DECOR',45)

def bench(l,x,y):
    l.cube('BENCH_SEAT',x,y,1.0,3,1,.3,'prop')
    l.cube('BENCH_BACK',x,y+.48,1.65,3,.25,1.3,'prop')
    for dx in (-1.2,1.2):l.cube('BENCH_LEG',x+dx,y,.5,.3,.45,1,'prop')

def table(l,x,y):
    l.cylinder('DANCE_TABLE',x,y,1.5,1.35,.25,'rose')
    l.cylinder('DANCE_TABLE_STEM',x,y,.7,.15,1.4,'prop')

def make_l1():
    l=Level(1,'The Gift','Christmas','Linear — exactly one route','dash',['dash'],
            'Christmas memory; symbolic presents and festive decorations, no invented plot outcome.')
    l.floor('START_CHRISTMAS_ROOM',-9,9,0,14)
    l.floor('FIRST_DASH_LANDING',-8,8,19,38)
    l.floor('CHRISTMAS_EXIT_CORRIDOR',-7,7,38,59)
    l.void(0,16.5,16,5);l.dash_cue(0,12)
    for x,y in [(-7,8),(7,8),(-6,27),(7,44),(-7,52)]:xmas_tree(l,x,y,.8)
    for x,y in [(-4,8),(4,7),(-5,25),(4,31)]:gift(l,x,y,.8)
    l.cube('PRESENT_BARRIER_LOW',0,30,.7,5,1.2,1.4,'prop')
    l.karma(0,10);l.karma(3,33);l.story(5,48,0,'A Christmas fragment')
    l.spawn=(0,4,0);l.exit=(0,55,0)
    l.route([(0,4),(0,12),(0,21),(3,28),(0,36),(0,55)])
    l.note('DASH OVER GAP',0,16.5);l.entry_exit();return l

def make_l2():
    l=Level(2,'The Donation','Giving away clothes at Goodwill',
            'One main route + one dead end','none',['dash'],
            'Clothes donation story; dead end rewards curiosity with a Story Item.')
    for name,y0,y1 in [('DROP_OFF',0,16),('SORTING',21,44),('EXIT_HALL',49,73)]:l.floor(name,-9,9,y0,y1)
    l.void(0,18.5,18,5);l.void(0,46.5,18,5)
    l.corridor('OPTIONAL_SIDE_CORRIDOR',[(7,32),(22,32)],7)
    l.floor('DEAD_END_DONATION_ROOM',20,38,26,39)
    l.cube('DEAD_END_WALL',38.5,32.5,2,.9,13,4,'wall')
    for x,y in [(-6,10),(5,25),(-5,40),(4,55),(29,32)]:rack(l,x,y)
    for x,y in [(-6,5),(6,12),(3,35),(31,28)]:l.cube('DONATION_BOX',x,y,.65,2,2,1.3,'prop')
    l.story(30,35,0,'Who received the donated clothes')
    l.karma(-3,27);l.karma(2,57)
    l.spawn=(0,4,0);l.exit=(0,68,0)
    l.dash_cue(0,14);l.dash_cue(0,42)
    l.route([(0,4),(0,13),(0,24),(0,43),(0,52),(0,68)])
    l.route([(0,32),(18,32),(30,32)],'DEAD END / STORY ITEM','OPTIONAL')
    l.note('DEAD END (NOT LEVEL EXIT)',29,34);l.entry_exit();return l

def make_l3():
    l=Level(3,'The False Exit','Halloween',
            'Linear looping route: exit visible behind, unreachable by Dash','none',['dash'],
            'Candy-themed Karma pickups. The apparent shortcut from spawn to rear exit is too wide for Dash.')
    l.floor('TRICK_OR_TREAT_START',-7,7,-7,11)
    l.floor('VISIBLE_REAR_EXIT',-8,8,-38,-28)
    # A continuous one-way-looking snake of walkway turning behind the player; no forks.
    l.corridor('LONG_FORWARD_DETOUR',[(0,9),(0,24),(24,24),(30,8),(30,-15),(19,-34),(0,-34)],8)
    l.void(0,-19.5,16,17)
    l.cube('FALSE_GAP_WARNING_POST',-7,-12,1.5,.8,1,3,'red')
    l.cube('FALSE_GAP_WARNING_POST',7,-12,1.5,.8,1,3,'red')
    for x,y in [(-5,4),(5,8),(5,22),(20,20),(26,-8),(16,-32),(3,-34)]:pumpkin(l,x,y,.9)
    for x,y in [(0,13),(22,23),(30,-2),(22,-29),(-1,-33)]:l.karma(x,y,style='candy')
    l.story(27,-16,0,'A Halloween memory')
    l.spawn=(0,1,0);l.exit=(0,-34,0)
    l.route([(0,1),(0,18),(24,24),(30,8),(30,-15),(19,-34),(0,-34)])
    l.note('EXIT VISIBLE BEHIND / GAP TOO LONG',0,-18)
    l.entry_exit();return l

def football_level(n=4):
    advanced=n==6
    l=Level(n,'The Stadium — First Voice' if not advanced else 'The Stadium — Risk',
            'Football (starts in locker room)',
            'Three routes: left stands / field / right stands',
            'scream_jump' if n==4 else 'wall_run',
            ['dash','scream_jump'] if n==4 else ['dash','scream_jump','wall_run'],
            'Repeating the football setting intentionally contrasts how the same place is remembered differently.')
    l.floor('LOCKER_ROOM',-12,12,0,17)
    l.floor('LOCKER_TUNNEL',-7,7,17,35)
    l.floor('THREE_ROUTE_SPLIT',-43,43,34,43)
    l.floor('END_ZONE_MERGE',-43,43,101,116)
    for x in [-9,-5,5,9]:l.cube('LOCKER',x,5,2,2,2,4,'prop')
    l.cube('LOCKER_ROOM_BENCH',0,8,0.7,8,1.4,1.4,'decoration')
    l.floor('LEFT_STANDS_LOWER',-42,-27,43,67 if not advanced else 57,0,'raised')
    l.floor('RIGHT_STANDS_LOWER',27,42,43,67 if not advanced else 57,0,'raised')
    l.floor('FIELD_LOWER',-24,24,43,68 if not advanced else 58,0,'football')
    if advanced:
        l.floor('LEFT_STANDS_FINAL',-42,-27,73,101,2.5,'raised')
        l.floor('RIGHT_STANDS_FINAL',27,42,73,101,2.5,'raised')
        l.floor('FIELD_FINAL',-24,24,75,101,3,'raised')
        l.wallrun(-26,65,18,0,6,'y');l.wallrun(26,65,18,0,6,'y')
        l.wallrun(13,66,20,0,6,'y')
        l.void(-34,65,16,16);l.void(34,65,16,16);l.void(0,66.5,48,17)
        for x in [-34,0,34]:l.dash_cue(x,55)
        for x in [-34,0,34]:l.scream_cue(x,80,2.5 if x else 3)
    else:
        l.floor('LEFT_STANDS_UPPER',-42,-27,67,101,3,'raised')
        l.floor('RIGHT_STANDS_UPPER',27,42,67,101,3,'raised')
        l.floor('FIELD_UPPER',-24,24,68,101,3,'raised')
        for x,y in [(-35,63),(0,64),(35,63)]:l.scream_cue(x,y)
        for x,y in [(-35,80),(0,83),(35,80)]:l.cube('RAISED_BLOCKING_ROW',x,y,4,8,2,2,'prop')
    bleachers(l,-42,-27,43,100,0,'left')
    bleachers(l,27,42,43,100,0,'right')
    goalpost(l,109)
    for y in [49,92]:
        for x in [-21,21]:l.cube('YARD_LINE_CORNER',x,y,.08,.4,6,.15,'blue','GUIDE')
    for x,y in [(-35,86),(0,89),(35,85)]:l.karma(x,y,3 if advanced else 3)
    l.story(-36,94,2.5 if advanced else 3, 'A memory from the stands')
    l.story(35,92,2.5 if advanced else 3, 'Another view of the same event')
    l.spawn=(0,7,0);l.exit=(0,111,0)
    l.route([(0,7),(0,29),(0,38),(-34,40),(-34,54),(-34,79),(-34,103),(0,111)],'LEFT STANDS','BRANCH')
    l.route([(0,7),(0,29),(0,38),(0,54),(0,78),(0,103),(0,111)],'FIELD','MAIN')
    l.route([(0,7),(0,29),(0,38),(34,40),(34,54),(34,79),(34,103),(0,111)],'RIGHT STANDS','BRANCH')
    l.note('ABILITY UNLOCK: SCREAM JUMP' if not advanced else 'ABILITY UNLOCK: WALL RUN',0,10)
    l.note('LEFT STANDS',-35,48);l.note('FIELD',0,48);l.note('RIGHT STANDS',35,48)
    l.entry_exit();return l

def create_maze(l,cols=7,rows=7,seed=5):
    rng=random.Random(seed)
    # Cells span x [-28,28], y [14,70], each 8 x 8 meters.
    cell=8; xmin=-28; ymin=14
    visited={(3,0)}; stack=[(3,0)]; openings=set()
    while stack:
        x,y=stack[-1]
        neighbors=[(nx,ny) for nx,ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]
                   if 0<=nx<cols and 0<=ny<rows and (nx,ny) not in visited]
        if not neighbors:stack.pop();continue
        nxt=rng.choice(neighbors);openings.add(tuple(sorted(((x,y),nxt))))
        visited.add(nxt);stack.append(nxt)
    # Added loops so it feels less like a single-path corridor.
    possible=[]
    for y in range(rows):
        for x in range(cols):
            for nx,ny in [(x+1,y),(x,y+1)]:
                if nx<cols and ny<rows:
                    e=tuple(sorted(((x,y),(nx,ny))))
                    if e not in openings:possible.append(e)
    openings.update(rng.sample(possible,4))
    l.floor('CEMETERY_MAZE_WALKABLE',xmin,xmin+cols*cell,ymin,ymin+rows*cell)
    # Outer bounds except y=14 entrance and y=70 chapel exit.
    l.cube('MAZE_LEFT_BOUNDARY',xmin-.5,ymin+rows*cell/2,2.6,1,rows*cell,5.2,'wall')
    l.cube('MAZE_RIGHT_BOUNDARY',xmin+cols*cell+.5,ymin+rows*cell/2,2.6,1,rows*cell,5.2,'wall')
    for j in range(cols):
        if j != 3:
            x=xmin+(j+.5)*cell
            l.cube('MAZE_BOTTOM_BOUNDARY',x,ymin-.5,2.6,cell,1,5.2,'wall')
            l.cube('MAZE_TOP_BOUNDARY',x,ymin+rows*cell+.5,2.6,cell,1,5.2,'wall')
    for y in range(rows):
        for x in range(cols):
            cx=xmin+(x+.5)*cell;cy=ymin+(y+.5)*cell
            if x<cols-1 and tuple(sorted(((x,y),(x+1,y)))) not in openings:
                l.cube('MAZE_DIVIDER_VERTICAL',xmin+(x+1)*cell,cy,2.6,.8,cell+.8,5.2,'wall')
            if y<rows-1 and tuple(sorted(((x,y),(x,y+1)))) not in openings:
                l.cube('MAZE_DIVIDER_HORIZONTAL',cx,ymin+(y+1)*cell,2.6,cell+.8,.8,5.2,'wall')
    # Find shortest route using BFS and annotate the guide overlay only.
    graph=defaultdict(list)
    for a,b in openings:graph[a].append(b);graph[b].append(a)
    start=(3,0);end=(3,6);queue=[start];parent={start:None}
    for node in queue:
        if node==end:break
        for nex in graph[node]:
            if nex not in parent:parent[nex]=node;queue.append(nex)
    p=[];cur=end
    while cur is not None:p.append(cur);cur=parent[cur]
    p=list(reversed(p))
    centers=lambda path:[(xmin+(x+.5)*cell,ymin+(y+.5)*cell) for x,y in path]
    # Collect a Story Item in an optional dead end not on the critical path.
    dead=[v for v in graph if len(graph[v])==1 and v not in p and v != start]
    target=max(dead,key=lambda v:abs(v[0]-3)+abs(v[1]-3)) if dead else (1,1)
    return centers(p),centers([target])[0]

def make_l5():
    l=Level(5,'The Farewell','Grim funeral','Maze-like cemetery / funeral chapel',
            'none',['dash','scream_jump'],'A funeral, distorted by grief; maze dead ends hold unreliable memory fragments.')
    l.floor('FUNERAL_ARRIVAL',-8,8,0,14)
    p,dead=create_maze(l)
    l.floor('CHAPEL',-14,14,70,91)
    l.cube('CHAPEL_FRONT',0,87,4,22,1.2,8,'dark')
    l.cube('COFFIN_PLACEHOLDER',0,81,1,5,2,2,'prop')
    for x,y in [(-24,20),(24,20),(-18,34),(19,53),(24,65),(-17,63)]:grave(l,x,y)
    l.story(dead[0],dead[1],0,'A funeral recollection')
    l.karma(0,8);l.karma(-2,80)
    l.scream_cue(5,76)
    l.spawn=(0,5,0);l.exit=(0,85,0)
    l.route([(0,5)]+p+[(0,77),(0,85)])
    l.note('MAZE / CEMETERY',0,41);l.entry_exit();return l

def make_l7():
    l=Level(7,'Two Paths','Valentine’s Day (romantic)',
            'Proposed: two curved park paths rejoin, optional memory garden',
            'none',['dash','scream_jump','wall_run'],
            'An emotionally romantic Valentine’s setting; the meaning is intentionally undecided.',True)
    l.floor('PARK_ENTRANCE',-10,10,0,17)
    l.floor('FORK_PLAZA',-25,25,15,26)
    l.floor('LEFT_WALKWAY_A',-27,-13,26,47)
    l.floor('LEFT_WALKWAY_B',-27,-13,53,77,2.3,'raised')
    l.floor('RIGHT_WALKWAY_A',13,27,26,47)
    l.floor('RIGHT_WALKWAY_B',13,27,53,77,2.3,'raised')
    l.floor('REUNION_PLAZA',-26,26,77,91,2.3,'raised')
    l.floor('HEART_EXIT',-10,10,91,108,2.3,'raised')
    l.void(-20,50,14,6);l.void(20,50,14,6)
    l.wallrun(-12.1,49.5,11,0,5);l.wallrun(12.1,49.5,11,0,5)
    for x,y in [(-20,64),(20,64)]:l.scream_cue(x,y,2.3)
    l.corridor('MEMORY_GARDEN_BRANCH',[(-21,65),(-37,65)],6,2.3,'raised')
    l.floor('STORY_GARDEN',-48,-34,59,73,2.3,'raised')
    l.story(-41,66,2.3,'Uncertain shared Valentine’s memory')
    for x,y in [(-16,20),(16,20),(-19,82),(19,82)]:heart(l,x,y,.75)
    for x,y in [(-23,31),(22,39),(-40,62)]:bench(l,x,y)
    for x,y in [(-20,75),(20,75),(0,102)]:l.karma(x,y,2.3)
    l.spawn=(0,5,0);l.exit=(0,103,2.3)
    l.route([(0,5),(0,21),(-20,22),(-20,43),(-20,60),(-20,83),(0,90),(0,103)],'LEFT PARK PATH','MAIN')
    l.route([(0,21),(20,22),(20,43),(20,60),(20,83),(0,90)],'RIGHT PARK PATH','BRANCH')
    l.route([(-20,65),(-41,65)],'STORY GARDEN','OPTIONAL')
    l.entry_exit();return l

def make_l8():
    l=Level(8,'The Dance','School dance (romantic)',
            'Proposed: dance floor, balconies and looping side paths',
            'none',['dash','scream_jump','wall_run'],
            'Romantic dance memory without committing to whether it was happy, awkward, or painful.',True)
    l.floor('FOYER',-10,10,0,17)
    l.floor('DANCE_FLOOR',-20,20,17,56)
    l.floor('LEFT_BALCONY_ENTRY',-32,-22,32,52,2.5,'raised')
    l.floor('LEFT_BALCONY_EXIT',-32,-22,66,88,2.5,'raised')
    l.floor('RIGHT_BALCONY_ENTRY',22,32,32,52,2.5,'raised')
    l.floor('RIGHT_BALCONY_EXIT',22,32,66,88,2.5,'raised')
    l.floor('CENTRAL_STAGE_LANDING',-17,17,68,86,3,'raised')
    l.floor('FINAL_HALL',-11,11,86,112,3,'raised')
    l.floor('LEFT_CLOAKROOM',-45,-31,17,31)
    l.corridor('CLOAKROOM_CONNECTION',[(-18,23),(-33,23)],7)
    l.story(-39,25,0,'A dance-night recollection')
    l.void(-27,59,10,14);l.void(27,59,10,14);l.void(0,62,36,12)
    l.wallrun(-21.5,58.5,20,2.5,4.5);l.wallrun(21.5,58.5,20,2.5,4.5)
    l.wallrun(14,61.5,17,0,6)
    for x,y in [(-13,40),(11,42),(0,73)]:l.scream_cue(x,y)
    for x,y in [(-12,28),(12,28),(-12,47),(12,48),(0,95)]:table(l,x,y)
    l.cube('STAGE_PLATFORM',0,82,3.8,10,4,1.6,'rose')
    for x,y in [(-26,78),(26,80),(0,101)]:l.karma(x,y,2.5 if x else 3)
    l.spawn=(0,5,0);l.exit=(0,106,3)
    l.route([(0,5),(0,24),(0,47),(0,57),(0,73),(0,93),(0,106)],'DANCE FLOOR','MAIN')
    l.route([(0,38),(-27,38),(-27,48),(-27,72),(-27,82),(0,94)],'LEFT BALCONY','BRANCH')
    l.route([(0,38),(27,38),(27,48),(27,72),(27,82),(0,94)],'RIGHT BALCONY','BRANCH')
    l.route([(-16,23),(-39,23)],'CLOAKROOM','OPTIONAL')
    l.entry_exit();return l

def make_l9():
    l=Level(9,'The Letter','College admission (romantic)',
            'Proposed: intersecting campus paths and elevated admissions hall',
            'none',['dash','scream_jump','wall_run'],
            'An admissions-memory setting connected to romance; no acceptance/rejection outcome imposed.',True)
    l.floor('CAMPUS_ARRIVAL',-12,12,0,18)
    l.floor('CENTRAL_COURTYARD',-26,26,18,37)
    l.floor('CENTRAL_CAMPUS_SPINE',-9,9,37,75)
    l.floor('WEST_WING_A',-42,-23,37,63)
    l.floor('EAST_WING_A',23,42,37,63)
    l.floor('CAMPUS_MIDDLE_CROSSING',-42,42,63,75,2,'raised')
    l.floor('WEST_WING_UPPER',-42,-23,82,104,4,'raised')
    l.floor('EAST_WING_UPPER',23,42,82,104,4,'raised')
    l.floor('CENTRAL_UPPER',-15,15,85,104,4,'raised')
    l.floor('ADMISSIONS_HALL',-36,36,104,118,4,'raised')
    l.floor('FINAL_LETTER_ROOM',-13,13,118,136,4,'raised')
    l.corridor('WEST_STUDENT_DETOUR',[(-33,52),(-54,52),(-54,88),(-33,88)],6,2,'raised')
    l.floor('DORM_MEMORY',-64,-50,62,74,2,'raised')
    l.void(-32.5,78.5,19,7);l.void(32.5,78.5,19,7)
    l.wallrun(-22,79,14,2,6);l.wallrun(22,79,14,2,6)
    l.wallrun(-15,83,18,0,7);l.wallrun(15,83,18,0,7)
    for x,y,z in [(-32,89,4),(32,91,4),(0,91,4)]:l.scream_cue(x,y,z)
    l.dash_cue(0,109,4)
    l.cube('ADMISSIONS_OFFICE_DESK',0,125,5,7,2,2,'gold')
    for x,y in [(-18,28),(18,28),(-35,51),(35,52)]:bench(l,x,y)
    for x,y,z in [(-33,110,4),(33,110,4),(0,131,4)]:l.karma(x,y,z)
    l.story(-57,67,2,'A letter or memory connected with admission')
    l.spawn=(0,5,0);l.exit=(0,132,4)
    l.route([(0,5),(0,27),(-33,31),(-33,53),(-33,69),(-33,89),(-33,109),(0,112),(0,132)],'WEST CAMPUS','MAIN')
    l.route([(0,27),(33,31),(33,53),(33,69),(33,89),(33,109),(0,112)],'EAST CAMPUS','BRANCH')
    l.route([(0,27),(0,65),(0,91),(0,112)],'CENTRAL CROSSING','BRANCH')
    l.route([(-33,52),(-54,52),(-54,67)],'DORM MEMORY','OPTIONAL')
    l.entry_exit();return l

def make_l10():
    l=Level(10,'The Break','Heartbroken',
            'Hectic / confusing presentation, simple critical path; difficult ability chains',
            'none',['dash','scream_jump','wall_run'],
            'End of Act 1. Disorienting visual repetitions reflect heartbreak; no invented character outcome.')
    l.floor('SHATTERED_ENTRY',-9,9,0,13)
    l.floor('ISOLATED_PLATFORM_A',-7,7,19,31,2,'raised')
    l.floor('ISOLATED_PLATFORM_B',-7,7,47,58,2,'raised')
    l.floor('ISOLATED_PLATFORM_C',-7,7,66,78,5,'raised')
    l.floor('ACT_ONE_END_PLATFORM',-11,11,84,103,5,'raised')
    l.void(0,16,18,6);l.void(0,39,18,16);l.void(0,62,18,8);l.void(0,81,18,6)
    l.wallrun(7.3,39,18,2,6,'y')
    l.wallrun(-7.3,39,18,2,6,'y')
    l.wallrun(7.8,80,14,5,7,'y')
    for x,y,z in [(0,8,0),(0,23,2),(0,52,2),(0,71,5)]:l.scream_cue(x,y,z)
    for x,y,z in [(0,11,0),(0,29,2),(0,58,2),(0,76,5)]:l.dash_cue(x,y,z)
    # Fake exits and overlapping impressions are decor only, not traversable alternate routes.
    for x,y,angle in [(-18,18,23),(18,25,-18),(-22,41,32),(21,54,-35),(-18,74,-16),(20,92,18)]:
        l.cube('FALSE_EXIT_FRAGMENT_NONWALKABLE',x,y,3,6,1.2,6,'heartbreak','DECOR',angle)
        l.cube('FLOATING_MEMORY_SHARD',x*1.18,y+2,7,3.5,2,3,'decoration','DECOR',angle+30)
    for x,y in [(-8,26),(8,53),(-8,75),(8,94)]:heart(l,x,y,.75)
    for x,y,z in [(0,24,2),(0,52,2),(0,92,5)]:l.karma(x,y,z)
    l.story(6,93,5,'The last contradiction of Act 1')
    l.spawn=(0,4,0);l.exit=(0,98,5)
    l.route([(0,4),(0,11),(0,22),(0,29),(0,49),(0,56),(0,69),(0,76),(0,87),(0,98)])
    l.note('ALL THREE ABILITIES / TIMING CHAIN',0,40)
    l.note('END OF ACT 1 / TRANSITION, NOT REPLAY',0,101)
    l.entry_exit();return l

def draw_plan(l):
    fig,ax=plt.subplots(figsize=(8.9,9.6),dpi=150)
    fig.patch.set_facecolor('#161C26');ax.set_facecolor('#1B2230')
    # draw walkable geometry, walls and some important props
    for item in l.items:
        r=item['role'];mat=item['material'];x,y,z=item['pos'];w,d,h=item['size'];a=item['rot']
        if r not in ('WALKABLE','WALLRUN','GUIDE','EXIT','SPAWN','PICKUP','KARMA_PICKUP','SOLID'):continue
        if r=='GUIDE' and item['name'].startswith('VOID_'):continue
        if r=='GUIDE' and 'CUE' not in item['name']:continue
        rgb=COLOR[mat]
        alpha= 0.95 if r=='WALKABLE' else .77 if r=='WALLRUN' else .4 if r=='SOLID' else 1
        if item['primitive']=='BOX':
            rect=Rectangle((x-w/2,y-d/2),w,d,facecolor=rgb,edgecolor='#313F52',linewidth=.6,alpha=alpha)
            if a: rect.set_transform(plt.matplotlib.transforms.Affine2D().rotate_deg_around(x,y,a)+ax.transData)
            ax.add_patch(rect)
        else:
            ax.add_patch(Circle((x,y),max(.7,w/2),facecolor=rgb,alpha=alpha,edgecolor='#202936'))
    routecolors={'MAIN':'#16E5CE','BRANCH':'#DCA7FF','OPTIONAL':'#FFA96F'}
    for r in l.routes:
        pts=np.asarray(r['points']);ax.plot(pts[:,0],pts[:,1],color=routecolors.get(r['kind'],'#E3E3E3'),
                        lw=2.7,ls='--' if r['kind']=='OPTIONAL' else '-',alpha=.95,zorder=8)
        for a,b in zip(pts[:-1],pts[1:]):
            mx,my=(np.asarray(a)+np.asarray(b))/2
            dx,dy=np.asarray(b)-np.asarray(a);length=math.hypot(dx,dy)
            if length>4:
                ax.annotate('',xy=(mx+dx/length*1.5,my+dy/length*1.5),
                            xytext=(mx-dx/length*1.5,my-dy/length*1.5),
                            arrowprops=dict(arrowstyle='->',lw=1.7,color=routecolors.get(r['kind'],'#E3E3E3')))
    # Essential notes, avoid crowding the plan with every pickup's annotations.
    for t in l.notes:
        label=t['text'];x,y=t['point']
        if 'STORY ITEM:' in label:label='STORY ITEM'
        elif len(label)>32:continue
        ax.annotate(label,xy=(x,y),xytext=(x+2.2,y+3),fontsize=6.5,color='#FFFFFF',
                    bbox=dict(boxstyle='round,pad=.2',facecolor='#263044',alpha=.9,edgecolor='none'))
    pts=[(it['pos'][0],it['pos'][1]) for it in l.items if it['role']=='WALKABLE']
    if pts:
        b=[(it['pos'][0],it['pos'][1],it['size'][0],it['size'][1]) for it in l.items if it['role']=='WALKABLE']
        lowx=min(x-w/2 for x,y,w,d in b)-8; highx=max(x+w/2 for x,y,w,d in b)+8
        lowy=min(y-d/2 for x,y,w,d in b)-8; highy=max(y+d/2 for x,y,w,d in b)+8
        ax.set_xlim(lowx,highx);ax.set_ylim(lowy,highy)
    ax.set_aspect('equal');ax.set_xticks([]);ax.set_yticks([])
    for spine in ax.spines.values():spine.set_visible(False)
    ax.set_title(f'LEVEL {l.n:02d}  •  {l.theme}\n{l.layout}',loc='left',fontsize=14,fontweight='bold',color='#F2F3F7',pad=16)
    fig.text(.11,.045,'TEAL: main path   |   LAVENDER: branching path   |   ORANGE: optional / dead end\n'
             'CYAN: Dash   |   PURPLE: Scream Jump   |   GOLD: Wall Run   |   YELLOW: Karma',
             color='#D2D9E5',fontsize=8)
    fig.savefig(PLANS/f'{l.id}_plan.png',bbox_inches='tight',pad_inches=.34,facecolor=fig.get_facecolor())
    plt.close(fig)

LEVELS_DATA=[make_l1(),make_l2(),make_l3(),football_level(4),make_l5(),football_level(6),
             make_l7(),make_l8(),make_l9(),make_l10()]
for l in LEVELS_DATA:
    p=l.export();draw_plan(l);print(l.id,l.theme,len(l.items),p.stat().st_size)
manifest={
    'project':'PURGATORY — ACT 1 GREYBOX',
    'coordinate_system':'Blender Z up, +Y forwards; coordinates in provisional meters',
    'purpose':'Editable spatial design draft, NOT gameplay logic nor finalized memory canon',
    'blender_scenes':'10 independent scenes; each level is automatically followed by next in the eventual game engine',
    'unlocks':{'level_01':'dash','level_04':'scream_jump','level_06':'wall_run'},
    'play_order':[f'level_{i:02d}' for i in range(1,11)],
    'level_select':False,'replay':False,
    'act_one_ending':'level_10 completion hands off to the Act 1 ending, NOT a level replay or selection screen',
    'guide_colors':COLOR,
    'levels':[l.manifest() for l in LEVELS_DATA]
}
(ROOT/'act1_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

# Act progression overview—small multiples of route shape.
fig,axes=plt.subplots(2,5,figsize=(21,10),dpi=140)
fig.patch.set_facecolor('#151C27')
for ax,l in zip(axes.ravel(),LEVELS_DATA):
    ax.set_facecolor('#1C2735')
    for it in l.items:
        if it['role']!='WALKABLE':continue
        x,y,_=it['pos'];w,d,_=it['size']
        r=Rectangle((x-w/2,y-d/2),w,d,color=COLOR[it['material']],alpha=.8)
        if it['rot']:
            r.set_transform(plt.matplotlib.transforms.Affine2D().rotate_deg_around(x,y,it['rot'])+ax.transData)
        ax.add_patch(r)
    for route in l.routes:
        pts=np.asarray(route['points']);ax.plot(pts[:,0],pts[:,1],lw=2.1,
          ls=':' if route['kind']=='OPTIONAL' else '-',color={'MAIN':'#10F5DC','BRANCH':'#DDA6FF','OPTIONAL':'#FFA56E'}[route['kind']])
    bb=[(it['pos'][0],it['pos'][1],it['size'][0],it['size'][1]) for it in l.items if it['role']=='WALKABLE']
    ax.set_xlim(min(x-w/2 for x,y,w,d in bb)-5,max(x+w/2 for x,y,w,d in bb)+5)
    ax.set_ylim(min(y-d/2 for x,y,w,d in bb)-5,max(y+d/2 for x,y,w,d in bb)+5)
    ax.set_xticks([]);ax.set_yticks([]);ax.set_aspect('equal')
    ax.set_title(f'{l.n:02d}  {l.theme}\n'+ ('Unlock: '+l.unlock.upper() if l.unlock!='none' else l.layout[:40]),
      fontsize=10,color='#FFFFFF',loc='left',pad=9)
    for s in ax.spines.values():s.set_visible(False)
fig.suptitle('PURGATORY  /  ACT 1   •   Ten sequential levels, no selection or replay',fontsize=20,color='white',y=.995)
fig.text(.08,.025,'Layout thumbnails are spatial design previews, NOT an in-game level-selection screen.',color='#B8C6D7',fontsize=12)
fig.subplots_adjust(left=.04,right=.98,bottom=.07,top=.89,wspace=.18,hspace=.28)
fig.savefig(ROOT/'act1_overview.png',bbox_inches='tight',facecolor=fig.get_facecolor())
plt.close(fig)
print('done')
