# Project-4

## K'von's mechanics test

Open `scenes/kvon_test.tscn` and press **F6** (run current scene), or choose K'von from the main menu. The course is built when the scene runs, so its platforms appear in the running game rather than the editor preview.

- Move: A/D or left/right arrows. Jump: Space. Scream Jump remains the existing E boost away from objects, with its original speed, pulse, and landing recharge. Microphone input, volume-based height, crouching, noise penalties, and the revised wall-jump push remain deferred.
- Dash: hold any of eight directions with WASD/arrows and press Shift. Travel 4 meters in 0.25 seconds, with no steering or jumping during the burst. No direction means no dash. Solid objects stop it early. The cooldown starts immediately and lasts 3 seconds; landing does not reset it. The player ring shows recharge. At +50 Karma or higher the cooldown is 2 seconds; at -50 or lower the distance is 6 meters. These values are captured when the dash starts.
- Wall Run: jump toward the purple wall, then dash up-right (W+D+Shift). Keep holding right over the top. A straight horizontal dash into a wall stops; an airborne diagonal or parallel dash can trigger a run. Runs use 8 meters/second with 30% gravity drift for at most 3 seconds. Holding away, landing, reaching the edge, or timing out ends the run. The same wall stays locked until landing or touching a different wall. After an E boost from a wall, contact with a different wall starts another run without a dash. Scream recharge still requires landing.
- Square objects glow within 2 meters. E opens choices above the object, then 1 adds 10 Karma or 2 subtracts 10. Each object allows one choice; E does nothing near resolved objects. The game keeps running while choices are open. Moving out of range closes them without changing Karma. The top bar marks -50, 0, and +50; Karma stays within -100 to +100.
- Collect all three gold fragments to reveal the placeholder diorama. Touch the green exit to finish. Red moving squares are hazards: three separate contacts restart the level. Falling also restarts the level.
- R restarts the level, restores its entry Karma, and resets fragments, objects, hits, and cooldowns. Esc returns to the menu. Karma carries across scene changes within the game session using SceneTree metadata `kvon_session_karma`; future level scripts can use the same key. This is not a disk save.

The PDF revision is adapted to 2D at 100 pixels per meter. Up/down dashes change height directly while gravity is disabled. `scripts/kvon_player.gd` contains movement rules; `scripts/kvon_test.gd` contains the course, contextual E, objects, hazards, Karma, and restart/exit logic. Project settings and the other test scenes are unchanged.

Open `project.godot` in Godot 4.7.2 and run the project to start at the main menu. The Aiden, John, K'von, and Kayla buttons open separate starter scenes in `scenes/`. Each scene has a Back to menu button.

The Web export preset is saved in `export_presets.cfg`. The exported game is in `build/web/`. Serve that directory with a local web server and open `index.html` through the server. For example, from `build/web/`, run `python -m http.server 8000` and visit `http://localhost:8000`.
