# Aiden gameplay plan

The player wakes in purgatory after death. Each room represents a year of their life, reconstructing places, people, and events through memory, emotion, and guilt. The player collects story items to learn what happened and why they are there. Some rooms show an unreliable version of the event before later rooms reveal more of the truth.

## 3D perspective direction

- Use low-poly 3D characters and environments with planar movement, framed from a high-angle overhead camera so the game reads with a 2D feel.
- Use a perspective camera with a very low field of view, around 5 degrees. Set its distance to keep the playable area in frame; the narrow field of view should flatten depth almost like an orthographic view.
- Tilt the camera downward and compose rooms so side walls and objects stay visible, echoing classic survival horror camera angles.
- The visual reference describes this approach in Unity. This project currently uses Godot; match the camera treatment there.
- The 3D test room uses this overhead perspective with a visible low-poly character and a waking animation.
- A second 3D scene uses a first-person camera to test the same room and mechanics from eye level. Its mouse look and camera-relative WASD movement let players inspect the room directly.
- **Signalis framing reference:** keep a small character inside a readable room composition, with the floor and far and side walls visible. Let the camera hold its framing until the character crosses a central area, then pan into the next view. The current test room uses a soft camera dead zone along the corridor, muted floor seams, and dark space outside the room. This is a perspective reference, not an instruction to copy Signalis assets or story. See the [rose-engine press kit](https://rose-engine.org/press/Presskit_SIGNALIS.html) and [official Steam page](https://store.steampowered.com/app/1262350/SIGNALIS/).

## Mechanics and meaning

- **Dash** (entire life): fleeing danger, responsibility, or difficult situations. Dash follows any held ground-plane direction in 3D, including diagonals. With no direction held, Shift does nothing and does not start the cooldown.
- **Scream jump** (age 12 onward): suppressed emotions and words become upward force. The gods' interference is another possible explanation.
- **Wall run** (age 16 onward): taking dangerous or unconventional routes around obstacles. Start an airborne dash toward a vertical wall. When the dash collides with it, the dash ends and a wall run begins if the dash also travels along the wall, parallel or up to 45 degrees from its length. A wall can only be touched, run on, or jumped from; crouching on it is unavailable.
- **Movement**: WASD moves the player in both 3D test views, and crouchwalking is slower. Y is reserved for yapping.
- **Karma**: consequences of choices in a year. Each level has a fixed karma requirement to complete its intended route. High and low karma should open different paths so players have reason to pursue either.
- **Story items**: optional collectibles that reveal the story behind a room.

## Planned progression

| Level | Focus | Layout |
| --- | --- | --- |
| 1 | Dash introduction | Very linear |
| 2 | Karma introduction | A couple of paths |
| 3 | Karma importance | Paths shaped by karma |
| 4 | Scream jump unlock | Branching layout |
| 5 | Dash, scream jump, karma | Branching layout |
| 6 | Wall run unlock | Wall run introduction |
| 7 | All mechanics | Multiple routes |
| 8 | All mechanics | Final memory and fate |

The game begins with a waking animation. The current overhead and first-person scenes are short 3D mechanic test rooms; the eight levels above remain a progression plan.
