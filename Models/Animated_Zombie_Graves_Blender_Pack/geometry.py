"""Shared mesh geometry used by both the Blender builder and the independent geometry preview.
All lengths are in Blender meters. No bpy or vtk imports required here.
"""
import math, random
from dataclasses import dataclass, field
from typing import List

random.seed(1709)
@dataclass
class Part:
    name: str
    vertices: list
    faces: list
    color: tuple
    collection: str = 'Static'
    roughness: float = 0.88
    metallic: float = 0.0

PARTS: List[Part] = []
COLORS = {
 'stone':(0.31,0.32,0.33), 'stone_light':(0.42,0.43,0.42),
 'stone_dark':(0.18,0.20,0.20), 'fissure':(0.09,0.105,0.10),
 'lichen':(0.23,0.31,0.24), 'letter':(0.11,0.115,0.12),
 'ground':(0.21,0.18,0.16), 'dirt':(0.27,0.205,0.155),
 'loam':(0.14,0.135,0.12), 'grass':(0.18,0.26,0.19),
 'grass2':(0.23,0.31,0.22), 'rock':(0.31,0.29,0.26),
 'skin':(0.34,0.41,0.31), 'skin_bright':(0.40,0.49,0.36),
 'skin_dark':(0.23,0.30,0.23), 'nails':(0.63,0.60,0.44),
 'bruise':(0.22,0.28,0.29), 'fabric':(0.17,0.18,0.15),
 'root':(0.24,0.19,0.15),
}

def add(name, vertices, faces, color, collection='Static', roughness=.92):
    p=Part(name, vertices, faces, color if isinstance(color,tuple) else COLORS[color], collection, roughness)
    PARTS.append(p)
    return p

def box(name, pos, sizes, color, collection='Static'):
    x,y,z=pos; a,b,c=[s/2 for s in sizes]
    v=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
       (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
    f=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return add(name,v,f,color,collection)

def ellipsoid(name, pos, radii, color, collection='Static', seg=12, rings=8):
    x,y,z=pos; rx,ry,rz=radii
    v=[]
    for j in range(rings+1):
        phi=math.pi*j/rings
        for i in range(seg):
            th=2*math.pi*i/seg
            v.append((x+rx*math.sin(phi)*math.cos(th),y+ry*math.sin(phi)*math.sin(th),z+rz*math.cos(phi)))
    faces=[]
    for j in range(rings):
        for i in range(seg):
            a=j*seg+i; b=j*seg+(i+1)%seg
            faces.append((a,b,b+seg,a+seg))
    return add(name,v,faces,color,collection)

def unit(v):
    d=sum(i*i for i in v)**.5 or 1.
    return tuple(i/d for i in v)
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def lerp(a,b,t):return tuple(a[i]*(1-t)+b[i]*t for i in range(3))

def tube(name, points, radius, color, collection='Static', sides=9, radii=None, cap=True):
    if len(points)<2:return
    verts=[]; faces=[]
    for j,p in enumerate(points):
        if j==0:d=unit(tuple(points[1][k]-p[k] for k in range(3)))
        elif j==len(points)-1:d=unit(tuple(p[k]-points[j-1][k] for k in range(3)))
        else:d=unit(tuple(points[j+1][k]-points[j-1][k] for k in range(3)))
        ref=(0,1,0) if abs(d[1])<.88 else (1,0,0)
        u=unit(cross(d,ref)); w=unit(cross(d,u))
        r=(radii[j] if radii is not None else radius)
        for i in range(sides):
            a=math.tau*i/sides
            verts.append(tuple(p[k]+r*(math.cos(a)*u[k]+math.sin(a)*w[k]) for k in range(3)))
    for j in range(len(points)-1):
        for i in range(sides):
            k=j*sides+i; next_k=j*sides+(i+1)%sides
            faces.append((k,next_k,next_k+sides,k+sides))
    if cap:
        faces.append(tuple(reversed(tuple(range(sides)))))
        faces.append(tuple((len(points)-1)*sides+i for i in range(sides)))
    return add(name,verts,faces,color,collection)

def extrude_xz(name, points, yfront, thickness, color):
    n=len(points)
    vf=[(x,yfront,z) for x,z in points]
    vb=[(x,yfront+thickness,z) for x,z in points]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n):fs.append((i,(i+1)%n,(i+1)%n+n,i+n))
    return add(name,vf+vb,fs,color)

def torus(name, center, major, minor, color, seg=32, sides=8, plane='XZ'):
    cx,cy,cz=center;verts=[];faces=[]
    for j in range(seg):
        a=math.tau*j/seg
        for k in range(sides):
            b=math.tau*k/sides
            d=major+minor*math.cos(b)
            if plane=='XZ':v=(cx+d*math.cos(a),cy+minor*math.sin(b),cz+d*math.sin(a))
            else:v=(cx+d*math.cos(a),cy+d*math.sin(a),cz+minor*math.sin(b))
            verts.append(v)
    for j in range(seg):
        for k in range(sides):
            a=j*sides+k;b=j*sides+(k+1)%sides
            c=((j+1)%seg)*sides+(k+1)%sides;d=((j+1)%seg)*sides+k
            faces.append((a,b,c,d))
    return add(name,verts,faces,color)

# --- Hand shapes are local to a rising-parent object at the emergence site ---
HAND_ROOTS=[(-4.75,-1.10,0.0),(-2.15,-1.20,0.0),(.35,-1.25,0.0),(3.0,-1.10,0.0),(4.45,-.85,0.0)]
HAND_POSES=[(-13,-.12,1.08), (15,.12,.94),(-8,-.06,1.12),(20,.16,.90),(-22,-.12,1.03)]

def hand(hand_id, seed=0):
    rnd=random.Random(5050+hand_id)
    group=f'Hand_{hand_id+1:02d}'
    tilt, curl, spread=HAND_POSES[hand_id]
    c='skin' if hand_id%2 else 'skin_bright'
    # ragged cloth cuff, torn points point down toward ground
    tube(f'{group}_Forearm',[(-.05,0,-.28),(-.05,-.015,.10),(-.02,0,.52),(.015,.015,.88)],.19,'skin_dark',group,
         radii=[.22,.22,.18,.16],sides=12)
    tube(f'{group}_WristTendon',[(-.012,-.07,.65),(.035,-.045,1.04),(.05,-.015,1.28)],.04,'skin_bright',group,sides=8)
    ellipsoid(f'{group}_Palm',(.03,0,1.27),(.345,.18,.47),c,group,seg=16,rings=12)
    ellipsoid(f'{group}_PalmPad',(.05,-.12,1.23),(.27,.075,.29),'skin_dark',group)
    # Slim, bent, bony fingers of different lengths and curl directions.
    lengths=[.78,1.02,.98,.72]
    offsets=[-.26,-.09,.105,.285]
    for j,(length,x) in enumerate(zip(lengths,offsets)):
        x1=x+(j-1.5)*.11*spread
        p0=(x,-.012,1.63)
        p1=(x1,-.075,1.72+length*.30)
        p2=(x1+(j-1.5)*.09,-.17+curl,1.72+length*.73)
        p3=(x1+(j-1.5)*.135,-.23+curl,1.72+length)
        tube(f'{group}_Finger{j+1}',[p0,p1,p2,p3],.075,c,group,radii=[.107,.092,.071,.043],sides=10)
        ellipsoid(f'{group}_Knuckle{j+1}',p1,(.097,.095,.102),'skin_dark',group)
        ellipsoid(f'{group}_Joint{j+1}',p2,(.076,.079,.083),'skin_bright',group)
        tip=tuple(p3[k]+(p3[k]-p2[k])*.26/(sum((p3[m]-p2[m])**2 for m in range(3))**.5) for k in range(3))
        tube(f'{group}_BlackClaw{j+1}',[p3,tip],.047,'nails',group,radii=[.054,.003],sides=8)
    # thumb swings sideways from the palm
    p0=(-.22,-.04,1.17);p1=(-.50,-.15,1.24);p2=(-.67,-.22,1.44);p3=(-.78,-.25,1.54)
    tube(f'{group}_OpposingThumb',[p0,p1,p2,p3],.095,c,group,radii=[.16,.115,.085,.048],sides=10)
    tube(f'{group}_ThumbNail',[p3,(-.88,-.31,1.62)],.05,'nails',group,radii=[.05,.002],sides=8)
    # stringy veins / exposed tendons; all built on the physical hand mesh
    for j in range(3):
        xp=-.18+j*.16
        tube(f'{group}_RaisedVein{j}',[(xp,-.17,.9),(xp+.05,-.19,1.16),(xp+.09,-.145,1.46)],.015,'skin_dark',group,radii=[.012,.025,.007],sides=6)
    # ragged sleeve: ring of soft cloth, plus dangling fabric strips
    tube(f'{group}_TornCuff',[(-.05,0,-.20),(-.05,0,.20)],.27,'fabric',group,radii=[.29,.24],sides=12)
    for j in range(7):
        a=j*math.tau/7
        x=.24*math.cos(a);y=.24*math.sin(a)
        tube(f'{group}_RaggedSleeve{j}',[(x*.78,y*.78,.21),(x,y,-.1-rnd.uniform(0,.16)),(x*.9,y*.9,-.29-rnd.uniform(0,.14))],.041,'fabric',group,radii=[.08,.064,.003],sides=6)

# -- All gravestones are distinct 3D shapes, not image planes --
def tombstones():
    # I: dark grey ancient Celtic cross with an outer weathered round stone ring
    x=-4.75;y=1.34
    box('01_CelticCross_Plinth',(x,y,.25),(2.05,.85,.5),'stone_dark')
    box('01_CelticCross_Base',(x,y,.59),(1.65,.64,.27),'stone')
    box('01_CelticCross_Stem',(x,y,1.91),(.48,.44,2.60),'stone_light')
    box('01_CelticCross_Bar',(x,y,2.46),(1.78,.45,.44),'stone_light')
    torus('01_CelticCross_AncientRing',(x,y-.02,2.46),.69,.12,'stone')
    ellipsoid('01_CelticCross_StoneBoss',(x,y-.24,2.45),(.17,.07,.17),'stone_dark')
    tube('01_CelticCross_Crack',[(-4.88,1.095,2.65),(-4.76,1.08,2.27),(-4.82,1.09,1.98),(-4.69,1.09,1.68)],.018,'fissure',sides=5)
    # II: worn rounded Victorian slate with engraved RIP in raised dark strokes
    x=-1.73; y=1.69
    pts=[(x-.82,.38),(x+.82,.38),(x+.82,1.98)]
    pts += [(x+.82*math.cos(a),1.98+.82*math.sin(a)) for a in [math.pi*j/12 for j in range(1,13)]]
    pts += [(x-.82,1.98)]
    extrude_xz('02_Victorian_ArchedHeadstone',pts,y-.23,.46,'stone')
    box('02_Victorian_Foot',(x,y,.22),(2.05,.75,.44),'stone_dark')
    # engraved simple 'RIP' strokes as actual geometry
    # all on front-facing y side; thin dark raised relief to read in an actual 3D render
    z=1.61; yf=y-.255
    def stroke(name, coords):tube(name,[(xx,yf,zz) for xx,zz in coords],.024,'letter',sides=6)
    stroke('02_R_Stem',[(x-.36,z-.3),(x-.36,z+.30)])
    stroke('02_R_Loop',[(x-.36,z+.3),(x-.10,z+.3),(x-.08,z+.05),(x-.35,z+.02)])
    stroke('02_R_Leg',[(x-.33,z+.02),(x-.06,z-.3)])
    stroke('02_I_Bar',[(x+.05,z+.3),(x+.27,z+.3)])
    stroke('02_I_Stem',[(x+.16,z+.3),(x+.16,z-.3)])
    stroke('02_I_Foot',[(x+.05,z-.3),(x+.27,z-.3)])
    # III: gothic faceted stone with an exaggerated pointed arch and small emblem
    x=1.54; y=1.55
    goth=[(x-.78,.32),(x+.78,.32),(x+.78,2.13),(x+.55,2.45),(x+.20,2.83),(x,3.00),
          (x-.20,2.83),(x-.55,2.45),(x-.78,2.13)]
    extrude_xz('03_Gothic_PointedTablet',goth,y-.25,.50,'stone_light')
    box('03_Gothic_Foundation',(x,y,.22),(1.93,.76,.44),'stone_dark')
    box('03_Gothic_CrossVertical',(x,y-.275,1.79),(.11,.060,.99),'stone_dark')
    box('03_Gothic_CrossHorizontal',(x,y-.275,1.97),(.59,.060,.11),'stone_dark')
    tube('03_Gothic_CrackedFace',[(x+.35,y-.266,.87),(x+.20,y-.266,1.07),(x+.27,y-.266,1.27),(x+.12,y-.266,1.44)],.025,'fissure',sides=5)
    # IV: tall tapered obelisk with pointed cap and visibly broken apex
    x=4.68; y=1.79
    box('04_Obelisk_LowerPlinth',(x,y,.25),(1.96,1.07,.48),'stone_dark')
    box('04_Obelisk_UpperPlinth',(x,y,.57),(1.55,.9,.33),'stone')
    # tapered shaft with squarish rectangular quad faces
    v=[]
    for zz,sc in [(.72,.77),(3.24,.40)]:
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:v.append((x+a*sc,y+b*sc*.77,zz))
    fs=[(0,3,2,1),(4,5,6,7)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
    add('04_Obelisk_TaperedShaft',v,fs,'stone_light')
    add('04_Obelisk_PyramidTip',[(x-.43,y-.37,3.24),(x+.43,y-.37,3.24),(x+.43,y+.37,3.24),(x-.43,y+.37,3.24),(x+.16,y+.08,3.78)],
        [(0,3,2,1),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'stone')
    tube('04_Obelisk_LongCrack',[(x-.12,y-.36,2.81),(x+.12,y-.36,2.55),(x+.03,y-.44,2.27),(x+.24,y-.48,1.94),(x+.10,y-.53,1.6)],.028,'fissure',sides=5)

def terrain():
    # Rolling graveyard earth, a genuinely tessellated ground mesh
    n=72;m=30;v=[];f=[]
    for j in range(m+1):
        y=-3.55+j*8/m
        for i in range(n+1):
            x=-7.40+i*14.8/n
            z=-.11+.05*math.sin(1.83*x+.8*y)*math.sin(1.3*y-1.71*x)+.025*math.cos(3.2*x+.7*y)
            v.append((x,y,z))
    for j in range(m):
        for i in range(n):
            k=j*(n+1)+i;f.extend([(k,k+1,k+n+2),(k,k+n+2,k+n+1)])
    add('Terrain_ActualMesh',v,f,'ground')
    # Grave soil raised around where hands actually emerge
    for i,(x,y,_) in enumerate(HAND_ROOTS):
        ellipsoid(f'Grave_{i+1:02d}_UnearthedSoil',(x,y,.015),(.86,.63,.20),'dirt',seg=16,rings=8)
        for k in range(5):
            a=(k+.25)*math.tau/5
            xx=x+.49*math.cos(a); yy=y+.32*math.sin(a)
            ellipsoid(f'Grave_{i+1:02d}_SoilClod{k}',(xx,yy,.11),(.18,.12,.10),'loam' if k%2 else 'dirt',seg=8,rings=5)
    rnd=random.Random(123456)
    for j in range(90):
        x=rnd.uniform(-7,7);y=rnd.uniform(-3.25,3.7)
        if any(abs(x-hx)<.40 and abs(y-hy)<.43 for hx,hy,_ in HAND_ROOTS): continue
        if rnd.random()<.55:
            radius=rnd.uniform(.047,.16)
            ellipsoid(f'Pebble_{j:03d}',(x,y,.005),(.85*radius,1.1*radius,.55*radius),'rock' if j%2 else 'stone_dark',seg=7,rings=5)
        else:
            for k in range(3):
                xx=x+rnd.uniform(-.09,.09); yy=y+rnd.uniform(-.09,.09)
                tube(f'Grass_{j:03d}_{k}',[(xx,yy,.025),(xx+rnd.uniform(-.15,.15),yy+.035,rnd.uniform(.12,.29))],.023,
                     'grass' if j%2 else 'grass2',radii=[.022,.003],sides=5)
    # weathered fragmented root strands near hands
    for i,(x,y,_) in enumerate(HAND_ROOTS):
        for j in range(3):
            a=.9*j+(.3*i)
            tube(f'Exposed_Root_{i}_{j}',[(x+.10*math.cos(a),y+.13*math.sin(a),.065),
                (x+.38*math.cos(a),y+.37*math.sin(a),.042),
                (x+.77*math.cos(a+.3),y+.65*math.sin(a+.3),.012)],.037,'root',radii=[.047,.031,.003],sides=6)
    # broken ground slabs adjacent to stones
    for i,x in enumerate([-4.6,-1.8,1.45,4.8]):
        box(f'Broken_Stone_Paving_{i}',(x-.2,2.55,.002),(.95,.54,.11),'stone_dark')

def create_all():
    PARTS.clear()
    terrain();tombstones()
    for i in range(len(HAND_ROOTS)):hand(i)
    return PARTS

if __name__ == '__main__':
    create_all(); print('Generated',len(PARTS),'parts,',sum(len(p.vertices) for p in PARTS),'vertices')
