# Project-4

## K'von's mechanics test

Open `scenes/kvon_test.tscn` and press **F6** (run current scene), or choose K'von from the main menu. The course is built when the scene runs, so its platforms appear in the running game rather than the editor preview.

- Move: A/D or left/right arrows. Jump: Space.
- Dash: Shift. Jump near the first gap, then dash in the air to cross it.
- Wall Run: hold right and W (or up arrow) against the purple wall, and keep moving right over its top.
- Scream Jump: E. Use it near the right edge of the middle platform to reach the high ledge. This is a movement boost with a visual pulse; no audio asset is included.
- Collect the three gold fragments by touching them. They automatically reconstruct the placeholder memory diorama. Walk to the end to choose action (+1 Karma) or inaction (-1 Karma).
- R restarts the whole test. Esc returns to the menu. Falls return you to the latest platform while keeping fragments. Dash and scream recharge on landing.

The memory text, layout, physics, and Karma values are prototype defaults, not final story or balance decisions. `scripts/kvon_player.gd` contains adjustable movement values at the top. `scripts/kvon_test.gd` contains platform rectangles, fragment positions, memory text, and the local Karma choice. Karma resets when restarting or leaving the test. Other test scenes use their existing shared scripts.

Open `project.godot` in Godot 4.7.2 and run the project to start at the main menu. The Aiden, John, K'von, and Kayla buttons open separate starter scenes in `scenes/`. Each scene has a Back to menu button.

The Web export preset is saved in `export_presets.cfg`. The exported game is in `build/web/`. Serve that directory with a local web server and open `index.html` through the server. For example, from `build/web/`, run `python -m http.server 8000` and visit `http://localhost:8000`.
