// Crayon twins of the zone golf courses (tools/gen-art-zone-courses.json) and the Godz-Touched place, drawn by
// tools/make-crayon-backgrounds.js with its helpers (passed in as h): the fridge-drawing style - a sky, hills, the
// fairway, a putting green with its flag, a bunker, a ball, and a landmark or two of the zone round the edges (the
// ogre stands in the middle).
module.exports = (h) => {
  const { S, fill, soft, line, curve, rect, hex, sky, skyBands, hills, sun, moon, cloud, stars, tree, palm, flower, waves,
    flag, rock, stalactites, lava, embers, floor, water, mushroom, vines, tower, mist, pillar, deadTree, tombstone, house,
    tent, hut, totem, pine, aurora, crystal, waterfall, statue, pyramid, ziggurat, skull, dab, circle, ellipse, OUTLINE, rain } = h;

  // A golf course: o.sky (a colour, or bands top to bottom), o.sun / o.moon [x, y], o.far / o.near (the hills' and the
  // fairway's colours), o.green, o.flag, o.sand (false: no bunker), o.back / o.front (the zone's things behind / in front).
  function course(c, r, o) {
    if (Array.isArray(o.sky)) skyBands(c, r, o.sky); else sky(c, r, o.sky);
    if (o.stars) stars(c, r, 24, 430);
    if (o.sun) sun(c, r, o.sun[0], o.sun[1], o.sun[2] || 100);
    if (o.moon) moon(c, r, o.moon[0], o.moon[1], 100);
    if (o.back) o.back(c, r);
    // (each course laid out its own way: its hills, green, bunker and ball placed by its own dice unless given)
    hills(c, r, o.farY || 560 + r() * 60, o.far, 50 + r() * 50, 1 + r() * 1.5, o.phase || r() * 6);
    hills(c, r, 760 + r() * 30, o.near, 30 + r() * 30, 1.5 + r(), r() * 6);
    const gx = o.greenX || (r() < 0.5 ? 760 + r() * 240 : 340 + r() * 200);
    fill(c, ellipse(gx, 812, 190, 46), o.green || "#8ee06a", r, { line: 12 });
    fill(c, ellipse(gx, 818, 26, 9), "#3a3236", r, { line: 6, hatch: 6 });
    flag(c, r, gx, 812, o.flag || "#e8463a");
    if (o.sand !== false) fill(c, ellipse(o.sandX || (gx > 640 ? 200 + r() * 260 : 820 + r() * 260), 990 + r() * 50, 120 + r() * 60, 34 + r() * 14), o.sand || "#f0d890", r, { line: 12 });
    if (o.front) o.front(c, r);
    fill(c, circle(o.ballX || 420 + r() * 420, 1060 + r() * 60, 14), "#ffffff", r, { line: 8, hatch: 8 });
  }
  const castle = (c, r, x, ground, w, col = "#c8c0b0", roof = "#4f6ab0") => {
    tower(c, r, x - w * 0.6, ground, w * 0.45, w * 1.6, col, roof);
    fill(c, rect(x - w * 0.5, ground - w, x + w * 0.5, ground), col, r);
    tower(c, r, x + w * 0.6, ground, w * 0.45, w * 1.4, col, roof);
  };
  const windmill = (c, r, x, ground) => {
    fill(c, [[x - 50, ground], [x - 32, ground - 220], [x + 32, ground - 220], [x + 50, ground]], "#c89a5a", r);
    for (const a of [0.4, 2.0, 3.6, 5.2]) line(c, [[x, ground - 210], [x + Math.cos(a) * 150, ground - 210 + Math.sin(a) * 150]], 18, "#8a5a2e", r);
  };
  const needle = (c, r, x, ground, h, col) => fill(c, [[x - 40, ground], [x - 16, ground - h], [x + 16, ground - h], [x + 40, ground]], col, r);

  return {
    zone_elwynn: (c, r) => course(c, r, { sky: ["#8ecbff", "#bfe2ff"], sun: [200, 200], far: "#6fc24a", near: "#5bb43a",
      back: (c, r) => { castle(c, r, 1050, 560, 120, "#f0ece0"); cloud(c, r, 700, 180, 150); },
      front: (c, r) => { tree(c, r, 110, 760, 220, "#4f9a2a"); house(c, r, 260, 760, 170, 130, "#e8d8b0", "#c0402e"); } }),
    zone_dunmorogh: (c, r) => course(c, r, { sky: ["#a8d8ff", "#e0f2ff"], far: "#f4f8ff", near: "#ffffff", green: "#d8ecff", sand: "#cfe0f0",
      back: (c, r) => { for (const x of [150, 380, 1080]) pine(c, r, x, 600, 200, true); },
      front: (c, r) => { pine(c, r, 120, 860, 260, true); house(c, r, 1120, 760, 170, 120, "#a0a0a8", "#6a5a4a", true); } }),
    zone_westfall: (c, r) => course(c, r, { sky: ["#ffd88a", "#ffeab0"], sun: [1060, 200], far: "#e8c04a", near: "#f0cc5a", green: "#d8c070",
      back: (c, r) => windmill(c, r, 260, 580),
      front: (c, r) => { for (let x = 30; x < S; x += 70) line(c, [[x, 1254], [x + 10, 1150]], 10, "#c8a03a", r); } }),
    zone_redridge: (c, r) => course(c, r, { sky: ["#ffb880", "#ffd6a8"], far: "#c8503a", near: "#b84a2e", green: "#c8705a", sand: "#e8a070",
      back: (c, r) => { water(c, r, 560, "#4aa8d8", "#d8f4ff", 6); house(c, r, 1060, 560, 150, 110, "#d8c8a0", "#8a3a2e"); },
      front: (c, r) => { rock(c, r, 120, 860, 120, "#a8402e"); } }),
    zone_needles: (c, r) => course(c, r, { sky: ["#7ac8ff", "#c8e8ff"], sun: [1080, 180], far: "#e8a060", near: "#f0b070", green: "#c89a6a", sand: "#fff0c0",
      back: (c, r) => { for (const [x, hgt] of [[180, 420], [420, 520], [860, 460], [1120, 380]]) { needle(c, r, x, 640, hgt, "#c8603a"); fill(c, ellipse(x, 640 - hgt, 34, 10), "#7ad65a", r, { line: 6 }); } } }),
    zone_lochmodan: (c, r) => course(c, r, { sky: ["#8ecbff", "#c8e8ff"], far: "#6a9a5a", near: "#5bb43a",
      back: (c, r) => { water(c, r, 600, "#3a8ad8", "#d8f4ff", 6); fill(c, rect(700, 420, 1254, 600), "#9a9aa0", r); for (let x = 760; x < 1254; x += 110) waterfall(c, r, x, 470, 600, 50); } }),
    zone_teldrassil: (c, r) => course(c, r, { sky: ["#3a2a6a", "#6a4aa0"], stars: true, moon: [1080, 180], far: "#4a6a8a", near: "#3a8a5a", green: "#5ac87a", flag: "#c8a0ff",
      front: (c, r) => { tree(c, r, 120, 800, 380, "#8a6ad8", 1.4); for (let i = 0; i < 12; i++) dab(c, 200 + r() * 900, 300 + r() * 400, 10, hex("#c8f0ff"), 0.9); } }),
    zone_darkshore: (c, r) => course(c, r, { sky: ["#2a3a6a", "#4a5a8a"], stars: true, moon: [220, 200], far: "#5a6a7a", near: "#3a6a4a", sand: "#c8c0a8",
      back: (c, r) => { water(c, r, 580, "#2a5a9a", "#bfe0ff", 7); for (const x of [900, 1000, 1100]) pillar(c, r, x, 600, 160, "#b8b8c8", true); } }),
    zone_duskwood: (c, r) => course(c, r, { sky: ["#2a1a4a", "#4a2a6a"], stars: true, moon: [1060, 190], far: "#2a3a2a", near: "#3a5a3a", green: "#4a7a4a", flag: "#c8a0ff",
      front: (c, r) => { deadTree(c, r, 110, 820, 300); tombstone(c, r, 260, 900, 70, -0.1); tombstone(c, r, 370, 920, 60, 0.15); mist(c, r, 760, 6, "#b8a8d8"); } }),
    zone_wetlands: (c, r) => course(c, r, { sky: ["#9ab0b8", "#c8d8d8"], far: "#5a7a5a", near: "#4a8a4a", sand: "#a89a6a",
      back: (c, r) => { tower(c, r, 1080, 590, 90, 260, "#6a6a6a", null); },
      front: (c, r) => { water(c, r, 1060, "#5a8a8a", "#c8e8e0", 5); rain(c, r, 30); } }),
    zone_hillsbrad: (c, r) => course(c, r, { sky: ["#8ecbff", "#d0ecff"], sun: [180, 190], far: "#7ac85a", near: "#6ab84a",
      back: (c, r) => { castle(c, r, 1100, 580, 90, "#a8a0a0", "#5a5a6a"); },
      front: (c, r) => { tree(c, r, 140, 790, 200, "#5bb43a"); for (const x of [100, 170]) dab(c, x, 700, 14, hex("#e8463a"), 0.95); } }),
    zone_arathi: (c, r) => course(c, r, { sky: ["#a8c8e8", "#d8e8f0"], far: "#c8c06a", near: "#9ab85a", green: "#a8d86a",
      back: (c, r) => { for (const [x, hh] of [[180, 140], [260, 170], [340, 130]]) pillar(c, r, x, 600, hh, "#a8a8b0", false); cloud(c, r, 900, 170, 170); } }),
    zone_alterac: (c, r) => course(c, r, { sky: ["#b8d0e8", "#e8f0f8"], far: "#ffffff", near: "#f0f4f8", green: "#d8e8f8", sand: "#c8d8e8",
      back: (c, r) => { castle(c, r, 1050, 580, 100, "#8a8a90", "#4a4a5a"); for (const x of [180, 400]) pine(c, r, x, 610, 190, true); } }),
    zone_badlands: (c, r) => course(c, r, { sky: ["#ffb060", "#ffd890"], sun: [1080, 170, 110], far: "#c8783a", near: "#d88a4a", green: "#b88a5a", sand: "#f0c080",
      back: (c, r) => { fill(c, rect(160, 380, 420, 600), "#a85a2e", r); fill(c, rect(900, 420, 1140, 600), "#a85a2e", r); },
      front: (c, r) => { skull(c, r, 160, 900, 1.6); } }),
    zone_swamp: (c, r) => course(c, r, { sky: ["#3a5a5a", "#5a7a6a"], far: "#3a5a3a", near: "#4a6a3a", green: "#5a8a4a", sand: "#7a7a4a",
      back: (c, r) => { ziggurat(c, r, 1050, 600, 260, 160); },
      front: (c, r) => { water(c, r, 1060, "#3a6a5a", "#a8d8c8", 5); vines(c, r, [80, 200], "#2a5a2a"); } }),
    zone_stranglethorn: (c, r) => course(c, r, { sky: ["#7ad8ff", "#c8f0ff"], sun: [180, 170], far: "#2a8a3a", near: "#3aa84a", green: "#6ad85a",
      back: (c, r) => { waterfall(c, r, 1080, 360, 600, 90); },
      front: (c, r) => { palm(c, r, 120, 820, 360, 1); palm(c, r, 1180, 860, 320, -1); flower(c, r, 260, 900, "#ff4a8a"); } }),
    zone_riverglades: (c, r) => course(c, r, { sky: ["#ffc890", "#ffe4b8"], sun: [1080, 210], far: "#7aba5a", near: "#6ab04a",
      back: (c, r) => { water(c, r, 610, "#4aa8d8", "#d8f4ff", 6); house(c, r, 260, 600, 160, 110, "#c8a070", "#8a3a2e"); house(c, r, 1000, 600, 140, 120, "#a8a8a0", "#5a5a6a", true); },
      front: (c, r) => { line(c, [[1080, 900], [1240, 900]], 10, "#8a5a2e", r); line(c, [[1080, 960], [1240, 960]], 10, "#8a5a2e", r); } }),
    zone_tirisfal: (c, r) => course(c, r, { sky: ["#8a9a7a", "#b8c0a0"], far: "#9aa04a", near: "#a8a85a", green: "#b8c06a", sand: "#c8b88a",
      front: (c, r) => { deadTree(c, r, 130, 820, 280, "#3a3a2a"); tombstone(c, r, 1100, 880, 80, 0.1); tombstone(c, r, 1200, 900, 60, -0.12); } }),
    zone_silverpine: (c, r) => course(c, r, { sky: ["#9aa8b8", "#c8d0d8"], far: "#4a6a5a", near: "#3a7a4a", mist: true,
      back: (c, r) => { for (const x of [120, 300, 980, 1160]) pine(c, r, x, 620, 260, false); },
      front: (c, r) => mist(c, r, 700, 5, "#d8e0e8") }),
    zone_durotar: (c, r) => course(c, r, { sky: ["#ffb070", "#ffd8a0"], sun: [1080, 180, 110], far: "#c8603a", near: "#d87a4a", green: "#c8905a", sand: "#f0b880",
      front: (c, r) => { hut(c, r, 160, 800, 180, "#a85a2e"); rock(c, r, 1150, 880, 110, "#b8503a"); } }),
    zone_mulgore: (c, r) => course(c, r, { sky: ["#7ac8ff", "#c8e8ff"], sun: [180, 170], far: "#8ad05a", near: "#7ac04a",
      back: (c, r) => { fill(c, rect(950, 380, 1200, 600), "#c8905a", r); fill(c, rect(1000, 300, 1160, 380), "#c8905a", r); },
      front: (c, r) => { tent(c, r, 170, 800, 170, "#d8a870"); totem(c, r, 330, 820, 180); } }),
    zone_barrens: (c, r) => course(c, r, { sky: ["#ffc870", "#ffe4a8"], sun: [1100, 170], far: "#c8a85a", near: "#d8b86a", green: "#b8b06a", sand: "#f0d890",
      back: (c, r) => { for (const x of [200, 1000]) { line(c, [[x, 600], [x, 470]], 16, "#6a4a2a", r); fill(c, ellipse(x, 460, 110, 30), "#7a8a3a", r); } } }),
    zone_ashenvale: (c, r) => course(c, r, { sky: ["#5a4a8a", "#8a7ab0"], far: "#3a6a4a", near: "#3a8a4a", green: "#5ac86a", flag: "#c8a0ff",
      front: (c, r) => { tree(c, r, 130, 820, 360, "#2a7a4a", 1.3); tree(c, r, 1150, 830, 320, "#3a6a8a", 1.2); for (let i = 0; i < 8; i++) dab(c, 300 + r() * 700, 400 + r() * 300, 10, hex("#c8f0ff"), 0.9); } }),
    zone_stonetalon: (c, r) => course(c, r, { sky: ["#a8c0d8", "#d8e4ec"], far: "#8a7a6a", near: "#7a8a5a", green: "#9ab86a", sand: "#c8b090",
      back: (c, r) => { fill(c, [[100, 600], [300, 260], [520, 600]], "#7a6a5a", r); fill(c, [[800, 600], [1040, 220], [1254, 600]], "#6a5a4a", r); } }),
    zone_desolace: (c, r) => course(c, r, { sky: ["#b8b0a8", "#d8d0c8"], far: "#9a9088", near: "#a8a098", green: "#a8a888", sand: "#c8c0a8",
      front: (c, r) => { skull(c, r, 170, 880, 2); line(c, curve([[1000, 900], [1080, 760], [1200, 720]], 8), 22, "#e8e0d0", r); tent(c, r, 1130, 820, 150, "#a8805a"); } }),
    zone_dustwallow: (c, r) => course(c, r, { sky: ["#c8d0a8", "#e0e4c0"], far: "#6a8a5a", near: "#5a8a4a", sand: "#a8a070",
      back: (c, r) => { castle(c, r, 1080, 590, 90, "#d8d0c0", "#4f6ab0"); },
      front: (c, r) => { water(c, r, 1060, "#5a8a7a", "#c8e8d8", 5); } }),
    zone_feralas: (c, r) => course(c, r, { sky: ["#7ac8d8", "#b8e4e8"], far: "#2a7a4a", near: "#2a9a4a", green: "#5ad86a",
      back: (c, r) => { waterfall(c, r, 1060, 340, 600, 80); },
      front: (c, r) => { tree(c, r, 120, 830, 420, "#1f6a3a", 1.5); pillar(c, r, 1180, 860, 180, "#c8c0b0", true); } }),
    zone_tanaris: (c, r) => course(c, r, { sky: ["#ffc860", "#ffe4a0"], sun: [1080, 180, 120], far: "#f0c070", near: "#f8d080", green: "#7ad65a", sand: false,
      back: (c, r) => { tower(c, r, 260, 600, 70, 220, "#a88a5a", "#6a5a3a"); },
      front: (c, r) => { palm(c, r, 1130, 820, 300, -1); water(c, r, 1100, "#4ab8d8", "#d8f8ff", 4); } }),
    zone_hinterlands: (c, r) => course(c, r, { sky: ["#8ecbff", "#c8e8ff"], far: "#4a9a4a", near: "#5aaa4a",
      back: (c, r) => { statue(c, r, 1080, 600, 220, "#a8a090", false); },
      front: (c, r) => { tree(c, r, 130, 800, 280, "#3a8a3a"); cloud(c, r, 600, 170, 150); } }),
    zone_searing: (c, r) => course(c, r, { sky: ["#c84a2a", "#ff8a4a"], far: "#3a2a2a", near: "#4a3a32", green: "#6a6a4a", sand: "#8a5a3a",
      back: (c, r) => { lava(c, r, 600, 680); },
      front: (c, r) => { embers(c, r, 30, 100, 900); } }),
    zone_burning: (c, r) => course(c, r, { sky: ["#8a2a1a", "#d84a2a"], far: "#2a1a1a", near: "#3a2a24", green: "#5a5a3a", sand: "#7a4a2a",
      back: (c, r) => { fill(c, [[700, 600], [960, 160], [1220, 600]], "#2a1a1a", r); },
      front: (c, r) => { lava(c, r, 1100, 1180); embers(c, r, 26, 100, 1000); } }),
    zone_azshara: (c, r) => course(c, r, { sky: ["#ffb880", "#ffd8b0"], far: "#c86a3a", near: "#8ab04a",
      back: (c, r) => { for (const x of [900, 1020, 1140]) pillar(c, r, x, 600, 200, "#c8c0e0", x === 1020); },
      front: (c, r) => { tree(c, r, 120, 820, 280, "#e8702a"); tree(c, r, 300, 830, 220, "#ffb02a"); } }),
    zone_felwood: (c, r) => course(c, r, { sky: ["#2a3a2a", "#3a5a3a"], far: "#2a3a1a", near: "#3a5a2a", green: "#5aa83a", flag: "#7aff4a", sand: "#5a6a3a",
      front: (c, r) => { deadTree(c, r, 120, 830, 320, "#2a2a1a"); fill(c, ellipse(1100, 1000, 140, 36), "#7aff4a", r, { line: 12 }); } }),
    zone_ungoro: (c, r) => course(c, r, { sky: ["#ffc890", "#ffe4b8"], far: "#3a8a3a", near: "#4aa83a", green: "#7ad85a",
      back: (c, r) => { fill(c, [[820, 600], [1000, 280], [1180, 600]], "#7a5a4a", r); for (let i = 0; i < 6; i++) dab(c, 960 + r() * 80, 240 - i * 30, 22, hex("#d8d0c8"), 0.6); },
      front: (c, r) => { mushroom(c, r, 140, 830, 300, "#ff7a3a", 1.2); crystal(c, r, 1160, 880, 140, "#7ad0ff"); } }),
    zone_blasted: (c, r) => course(c, r, { sky: ["#8a2a2a", "#c84a3a"], far: "#a8402e", near: "#b8503a", green: "#a87a5a", sand: "#d88a6a",
      back: (c, r) => { fill(c, rect(940, 330, 1180, 600), "#4a3a3a", r); fill(c, rect(990, 380, 1130, 600), "#7aff6a", r); } }),
    zone_wpl: (c, r) => course(c, r, { sky: ["#a8a890", "#c8c8b0"], far: "#9a9a5a", near: "#8a9a4a", green: "#a8b86a", sand: "#c8b88a",
      back: (c, r) => windmill(c, r, 1060, 590),
      front: (c, r) => { deadTree(c, r, 130, 820, 260, "#4a3a2a"); } }),
    zone_hyjal: (c, r) => course(c, r, { sky: ["#3a3a7a", "#7a6ab0"], stars: true, far: "#3a6a5a", near: "#4a8a5a", green: "#7ad87a", flag: "#c8a0ff",
      back: (c, r) => { line(c, [[640, 600], [640, 120]], 120, "#6a5a4a", r); fill(c, ellipse(640, 140, 320, 120), "#7ac8a0", r); },
      front: (c, r) => { for (let i = 0; i < 10; i++) dab(c, 150 + r() * 950, 350 + r() * 350, 11, hex("#d8f4ff"), 0.9); } }),
    zone_epl: (c, r) => course(c, r, { sky: ["#5a4a7a", "#8a7aa0"], far: "#6a6a6a", near: "#7a7a6a", green: "#8a9a7a", sand: "#a8a090", flag: "#c8a0ff",
      back: (c, r) => { fill(c, [[820, 260], [1100, 200], [1160, 300], [880, 360]], "#3a3a5a", r); },
      front: (c, r) => { deadTree(c, r, 130, 820, 300, "#3a3a3a"); tombstone(c, r, 1130, 890, 80, 0.12); } }),
    zone_winterspring: (c, r) => course(c, r, { sky: ["#2a3a7a", "#5a6aa8"], stars: true, far: "#e8f0ff", near: "#ffffff", green: "#d8ecff", sand: "#c8d8e8",
      back: (c, r) => aurora(c, r, ["#7aff9a", "#7ad8ff", "#c87aff"]),
      front: (c, r) => { pine(c, r, 120, 840, 300, true); pine(c, r, 1160, 860, 260, true); } }),
    zone_silithus: (c, r) => course(c, r, { sky: ["#e8c060", "#f8e0a0"], sun: [1080, 180], far: "#d8b060", near: "#e0c070", green: "#c8b06a", sand: false,
      front: (c, r) => { for (const [x, hh] of [[140, 220], [260, 160]]) fill(c, [[x - 50, 840], [x, 840 - hh], [x + 50, 840]], "#a87a3a", r); crystal(c, r, 1160, 880, 150, "#c87aff"); } }),
    zone_deadwind: (c, r) => course(c, r, { sky: ["#3a3a4a", "#5a5a6a"], far: "#4a4a4a", near: "#5a5a4a", green: "#6a7a5a", sand: "#8a8a7a", flag: "#c8a0ff",
      back: (c, r) => { tower(c, r, 1060, 600, 140, 460, "#3a3a4a", "#2a2a3a"); for (const y of [260, 340, 420]) dab(c, 1060, y, 12, hex("#c8a0ff"), 0.95); },
      front: (c, r) => { deadTree(c, r, 130, 820, 280, "#3a3a3a"); line(c, [[300, 120], [340, 220], [310, 260], [360, 360]], 12, "#fff6a0", r); } }),
    zone_moonglade: (c, r) => course(c, r, { sky: ["#2a3a6a", "#4a5a9a"], stars: true, moon: [640, 170], far: "#3a6a5a", near: "#4a8a5a", green: "#7ad87a", flag: "#c8a0ff",
      back: (c, r) => water(c, r, 610, "#3a5a9a", "#c8e0ff", 5),
      front: (c, r) => { hut(c, r, 160, 800, 160, "#8a6a4a"); flower(c, r, 1100, 900, "#c87aff"); flower(c, r, 1180, 940, "#7ad8ff"); } }),
    // Godz-Touched: a golden beam of light down from the clouds onto a mossy clearing, giant ogre faces in the cliffs.
    bg_godz_touched: (c, r) => {
      skyBands(c, r, ["#5a4a7a", "#a87a8a", "#ffc890"]);
      for (const x of [200, 640, 1080]) cloud(c, r, x, 140, 200, "#d8c8e0");
      fill(c, [[520, 120], [760, 120], [920, 900], [360, 900]], "#ffe07a", r, { outline: null, hatch: 22 });
      for (const x of [110, 1144]) {
        fill(c, rect(x - 110, 300, x + 110, 800), "#8a7a6a", r);
        dab(c, x - 40, 470, 18, OUTLINE, 0.95); dab(c, x + 40, 470, 18, OUTLINE, 0.95);
        line(c, curve([[x - 50, 600], [x, 570], [x + 50, 600]], 6), 14, OUTLINE, r);
        fill(c, [[x - 46, 600], [x - 30, 540], [x - 18, 604]], "#f0e8d0", r, { line: 6, hatch: 5 });
        fill(c, [[x + 18, 604], [x + 30, 540], [x + 46, 600]], "#f0e8d0", r, { line: 6, hatch: 5 });
      }
      hills(c, r, 840, "#5a8a4a", 30, 2);
      for (let i = 0; i < 16; i++) fill(c, circle(480 + r() * 320, 250 + r() * 600, 14), "#ffd23f", r, { line: 6, hatch: 6 });
    },
  };
};
