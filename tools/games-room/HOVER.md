# Games Room hover outlines

Five native UI contour masks follow visible cupboard, easel/canvas, Couronne table/legs, arcade and claw silhouettes in the approved overview. They are cropped transparent gold textures, not rectangular button highlights and not repainted room art. Placement tracks the same 14px artwork bleed and proportional resize as the stations.

Hover/focus behavior: only the hovered station targets .85 opacity; 120ms exponential fade, additive blending. On leave it fades away; hiding the page resets every glow immediately so returning from a game has no stale highlight. Existing tooltip and launch behavior stays intact.

Files: GamesRoomGlows.lua (generated placement, loaded before GamesRoom.lua), Media/GamesRoom/Hover_<station>.blp, and updated GamesRoom.lua. Source contours/generator: tools/build-games-hover.js; it writes reproducible staging assets to output/games-hover for review. Preview PNG masks also match the browser mockup.

Verified native Lua syntax, texture decoding/transparency, placement/resize, exclusive hover, fade-in/out and hide cleanup. Browser inspection checks alignment against the room, with special refinement around the Couronne legs and easel. New texture assets require a full WoW restart before the in-client visual check.

## In-client screenshot fit pass

Reviewed the five screenshots WoWScrnShot_103126_115617 through 115627. Corrected the source coordinate dimensions to 1491x1055. Replaced the cupboard's angular crest shortcuts with a dense trace of its visible gold edge; corrected the actual finial positions. Retraced the arcade's inset shoulder/left side, the easel's real wood/clamp, and the claw base with separate feet instead of a line across the floor. Couronne's front leg now continues to the image boundary instead of closing across the visible bulb; other leg edges were tightened. Reduced glow core and halo intensity by about a quarter. Browser comparison and native hover/texture tests pass. In-client review follows after refreshing WoW's texture cache.
