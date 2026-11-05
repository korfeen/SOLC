# Games Room: addon step 1

The approved room overview is now the Games sidebar page. Its art fills the page and extends 14 pixels beneath the wooden frame. The room retains its existing composition. Hover objects for their labels; the cupboard and easel launch existing puzzle/paint practice, Couronne and Claw open their existing native screens. The arcade is hover-only until its focused view is migrated. No browser-focused cabinet assets or camera animations are installed in this step.

The previous Puzzle sidebar entry is now reached through Games; its practice, Jigsaw, duels, painting and replays remain available. A Games Room button returns to the overview. The launcher preserves active duel countdowns/races and closes stale viewers before changing practice mode. The room still works when the optional SOLC_Puzzle companion is disabled, with a helpful message for its two stations.

Runtime: GamesRoom.lua; Media/GamesRoom/Overview.blp (700236 bytes); GamesRoom.lua added after API.lua in SOLC.toc; Games navigation added to UI.lua; companion Page.lua gets parent navigation and the practice launcher. Source painting: tools/games-room/overview.png. Rebuild from the main repo with node tools/build-games-room-art.js. Source/tool folders are excluded from the release package.

Validation: Lua syntax, native texture decode, room registration, full-bleed bounds, five proportional hover/click regions, easel-over-cupboard hit priority, game routing, companion-disabled fallback, resizing, viewer cleanup and active-duel preservation. Existing Jigsaw size/seam/drag/completion checks also pass. Actual WoW visuals need an in-client check after a full restart to load the new TOC file and texture.

Next step: migrate one focused view at a time after reviewing the overview in WoW.
