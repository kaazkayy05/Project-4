# Project-4

Open `project.godot` in Godot 4.7.2 and run the project to start at the main menu. John, K'von, and Kayla each have a starter scene. Aiden's first choice, **3D, but looks 2D**, opens the overhead low-poly game. The second choice, **3D**, opens a first-person version of the same test room. Both scenes include a waking moment, dash, scream jump, wall running, karma pickups, a story item, high and low karma exits, and a return button. WASD moves, holding Ctrl crouchwalks, and Shift dashes only when a direction is held. An airborne dash into a vertical wall begins a wall run when its direction is within 45 degrees of the wall's length. In first-person mode, move the mouse to look around, press Esc to release the cursor, and click the room to recapture it. The on-screen HUD shows the other controls.

The story, mechanic rules, and eight-level plan are in `design/aiden-gameplay.md`.

The Web export preset is saved in `export_presets.cfg`. The exported game is in `build/web/`. Serve that directory with a local web server and open `index.html` through the server. For example, from `build/web/`, run `python -m http.server 8000` and visit `http://localhost:8000`.
