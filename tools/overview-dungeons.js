// The dungeons' and their end bosses' crayon scenes for the Overview's feed details (FeedDetail.lua), used by
// tools/make-overview-art.js: a scene per dungeon (DUNGEONS) and per end boss (BOSSES), keyed by the dungeon's key in
// Achievements.lua (upper case). 1024x512; only about x 150..870 shows, so the middle carries it. The bosses stand in
// the middle, as tall as the picture, in front of a bit of their dungeon.
// Forever's own bosses (Durgen Dirgehammer, Rath'mael, the Relic Guardian, Sonya Darkhallow, the Wild King) are drawn
// from their names, not their looks.

module.exports = (h) => {
  const { W, H, fill, soft, line, curve, rect, wall, floor, dots, sparkle, gear, flame, arch, rays, circle, ellipse, star,
    rotate, hex, dab, OUTLINE } = h;

  // --- Pieces ---------------------------------------------------------------------------------------------------
  const bands = (c, r, cols, y0 = 0, y1 = H) => {
    const step = (y1 - y0) / cols.length;
    cols.forEach((col, i) => soft(c, rect(-20, y0 + i * step - 8, W + 20, y0 + (i + 1) * step + 8), col, r));
  };
  function ground(c, r, y, col, amp = 20, waves = 2, phase = 0) {
    const pts = [];
    for (let i = 0; i <= 20; i++) pts.push([-20 + (i / 20) * (W + 40), y - Math.sin((i / 20) * Math.PI * waves + phase) * amp]);
    fill(c, [[-20, H + 20], ...pts, [W + 20, H + 20]], col, r);
  }
  const moon = (c, r, x, y, rad, col = "#fff2a8") => fill(c, circle(x, y, rad), col, r);
  const stars = (c, r, n, y1 = 220) => dots(c, r, n, "#fff2a8", 3, [0, 0, W, y1]);
  function pillar(c, r, x, top, bottom, w, col, cap) {
    fill(c, rect(x - w / 2, top, x + w / 2, bottom), col, r);
    fill(c, rect(x - w / 2 - 12, top - 20, x + w / 2 + 12, top + 4), cap || col, r, { line: 10 });
    fill(c, rect(x - w / 2 - 12, bottom - 6, x + w / 2 + 12, bottom + 16), cap || col, r, { line: 10 });
  }
  function tomb(c, r, x, y, w, ht, col = "#8a8890") {
    fill(c, curve([[x - w / 2, y], [x - w / 2, y - ht * 0.8], [x, y - ht], [x + w / 2, y - ht * 0.8], [x + w / 2, y]], 8), col, r);
    line(c, [[x, y - ht * 0.78], [x, y - ht * 0.3]], 6, OUTLINE, r);
    line(c, [[x - w * 0.2, y - ht * 0.6], [x + w * 0.2, y - ht * 0.6]], 6, OUTLINE, r);
  }
  function banner(c, r, x, top, w, ht, col, emblem) {
    line(c, [[x - w / 2 - 10, top], [x + w / 2 + 10, top]], 10, "#6a4020", r);
    fill(c, [[x - w / 2, top], [x + w / 2, top], [x + w / 2, top + ht], [x, top + ht - 30], [x - w / 2, top + ht]], col, r);
    if (emblem) fill(c, circle(x, top + ht * 0.4, w * 0.22), emblem, r, { line: 8 });
  }
  function bars(c, r, x0, x1, top, bottom, n, col = "#5a5f66") {
    for (let i = 0; i <= n; i++) {
      const x = x0 + (i / n) * (x1 - x0);
      line(c, [[x, top], [x, bottom]], 14, col, r);
    }
    line(c, [[x0 - 10, top], [x1 + 10, top]], 18, col, r);
    line(c, [[x0 - 10, bottom], [x1 + 10, bottom]], 18, col, r);
  }
  function shelf(c, r, x0, x1, y, colors) {
    fill(c, rect(x0, y, x1, y + 18), "#6a4020", r, { line: 10 });
    for (let x = x0 + 10, i = 0; x < x1 - 30; i++) {
      const w = 18 + (i * 7) % 16, ht = 56 + (i * 13) % 30;
      fill(c, rect(x, y - ht, x + w, y), colors[i % colors.length], r, { line: 8 });
      x += w + 4;
    }
  }
  const crystal = (c, r, x, y, ht, col) =>
    fill(c, [[x - ht * 0.22, y], [x - ht * 0.16, y - ht * 0.7], [x, y - ht], [x + ht * 0.16, y - ht * 0.7], [x + ht * 0.22, y]], col, r, { line: 10 });
  function tree(c, r, x, y, ht, col = "#2f6a2a", trunk = "#5a3a1e") {
    line(c, [[x, y], [x, y - ht * 0.5]], ht * 0.12, trunk, r);
    fill(c, circle(x, y - ht * 0.66, ht * 0.34), col, r);
  }
  function pine(c, r, x, y, ht, col = "#1f4a2a") {
    line(c, [[x, y], [x, y - ht * 0.3]], ht * 0.08, "#3a2414", r);
    fill(c, [[x - ht * 0.3, y - ht * 0.2], [x, y - ht], [x + ht * 0.3, y - ht * 0.2]], col, r);
  }
  // A castle: a wall with a gate and towers with pointed roofs.
  function castle(c, r, x, base, w, ht, col, roof, windows = "#ffd23f") {
    fill(c, rect(x - w / 2, base - ht * 0.55, x + w / 2, base), col, r);
    for (const tx of [x - w / 2, x + w / 2, x]) {
      const tw = tx === x ? w * 0.22 : w * 0.18, th = tx === x ? ht : ht * 0.8;
      fill(c, rect(tx - tw / 2, base - th, tx + tw / 2, base), col, r);
      fill(c, [[tx - tw / 2 - 10, base - th], [tx, base - th - tw * 0.9], [tx + tw / 2 + 10, base - th]], roof, r);
      fill(c, rect(tx - 9, base - th * 0.75, tx + 9, base - th * 0.75 + 26), windows, r, { line: 6 });
    }
    fill(c, ellipse(x, base, w * 0.1, ht * 0.2).filter(([, y]) => y <= base), "#1a1014", r);
  }
  function lava(c, r, y, a = "#ff7a1a", b = "#ffd23f") {
    fill(c, rect(-20, y, W + 20, H + 20), a, r);
    for (let i = 0; i < 9; i++) {
      const x = 40 + i * 115, yy = y + 24 + (i % 3) * 22;
      line(c, curve([[x, yy], [x + 30, yy - 10], [x + 70, yy]], 6), 10, b, r);
    }
  }
  function water(c, r, y, col = "#2a6aa0", wave = "#8ac8f0") {
    fill(c, rect(-20, y, W + 20, H + 20), col, r);
    for (let i = 0; i < 9; i++) {
      const x = 30 + i * 118, yy = y + 30 + (i % 3) * 28;
      line(c, curve([[x, yy], [x + 30, yy - 12], [x + 60, yy]], 6), 6, wave, r);
    }
  }
  function skull(c, r, x, y, s, col = "#f0ece0") {
    fill(c, circle(x, y, s), col, r, { line: 8 });
    fill(c, rect(x - s * 0.55, y + s * 0.6, x + s * 0.55, y + s * 1.1), col, r, { line: 8 });
    dab(c, x - s * 0.4, y, s * 0.28, OUTLINE, 0.95);
    dab(c, x + s * 0.4, y, s * 0.28, OUTLINE, 0.95);
  }
  const bone = (c, r, x0, y0, x1, y1) => {
    line(c, [[x0, y0], [x1, y1]], 14, "#f0ece0", r);
    for (const [x, y] of [[x0, y0], [x1, y1]]) fill(c, circle(x, y, 12), "#f0ece0", r, { line: 6 });
  };
  const egg = (c, r, x, y, s, col) => fill(c, ellipse(x, y, s * 0.7, s), col, r);
  function torch(c, r, x, y) {
    line(c, [[x, y], [x, y - 120]], 16, "#6a4020", r);
    flame(c, r, x, y - 115, 28, 60);
  }
  function hut(c, r, x, base, w, col, roof) {
    fill(c, rect(x - w / 2, base - w * 0.55, x + w / 2, base), col, r);
    fill(c, [[x - w / 2 - 30, base - w * 0.5], [x, base - w * 1.05], [x + w / 2 + 30, base - w * 0.5]], roof, r);
    fill(c, rect(x - w * 0.12, base - w * 0.32, x + w * 0.12, base), "#2a1a10", r);
  }
  function thorns(c, r, y, col = "#4a3a20", spike = "#c8b890") {
    for (let i = 0; i < 4; i++) {
      const x = -60 + i * 290;
      const vine = curve([[x, y + 60], [x + 90, y - 40], [x + 200, y + 10], [x + 300, y - 70]], 6);
      line(c, vine, 34, col, r);
      for (let k = 3; k < vine.length - 1; k += 5) {
        const [vx, vy] = vine[k];
        fill(c, [[vx - 14, vy - 6], [vx + 4, vy - 60], [vx + 16, vy - 6]], spike, r, { line: 8 });
        fill(c, [[vx - 6, vy + 10], [vx - 10, vy + 54], [vx + 10, vy + 12]], spike, r, { line: 8 });
      }
    }
  }
  function window(c, r, x, top, w, ht, cols) {
    fill(c, [...curve([[x - w / 2, top + ht], [x - w / 2, top + w * 0.4], [x, top], [x + w / 2, top + w * 0.4], [x + w / 2, top + ht]], 10)], "#3a3040", r);
    cols.forEach((col, i) => {
      const y0 = top + w * 0.35 + i * ((ht - w * 0.35) / cols.length), y1 = y0 + (ht - w * 0.35) / cols.length - 8;
      soft(c, rect(x - w / 2 + 14, y0, x - 4, y1), col, r);
      soft(c, rect(x + 4, y0, x + w / 2 - 14, y1), cols[(i + 1) % cols.length], r);
    });
  }
  function weaponRack(c, r, x, base) {
    fill(c, rect(x - 90, base - 20, x + 90, base), "#6a4020", r);
    for (const [dx, col] of [[-60, "#c0c8d0"], [0, "#d0a040"], [60, "#c0c8d0"]]) {
      line(c, [[x + dx, base - 20], [x + dx, base - 200]], 12, col, r);
      fill(c, [[x + dx - 22, base - 170], [x + dx, base - 230], [x + dx + 22, base - 170]], "#c0c8d0", r, { line: 8 });
    }
  }
  function shield(c, r, x, y, s, col, emblem) {
    fill(c, [...curve([[x - s, y - s], [x - s, y + s * 0.4], [x, y + s * 1.2]], 8), ...curve([[x, y + s * 1.2], [x + s, y + s * 0.4], [x + s, y - s]], 8).slice(1)], col, r);
    if (emblem) fill(c, circle(x, y, s * 0.4), emblem, r, { line: 6 });
  }
  function mech(c, r, x, base) {  // a little gnome robot
    fill(c, rect(x - 50, base - 140, x + 50, base - 50), "#a0a8b0", r);
    fill(c, circle(x, base - 160, 30), "#a0a8b0", r);
    dab(c, x - 10, base - 162, 7, hex("#ff4a3a"), 0.95);
    dab(c, x + 10, base - 162, 7, hex("#ff4a3a"), 0.95);
    for (const s of [-1, 1]) line(c, [[x + s * 30, base - 50], [x + s * 36, base]], 18, "#7a8088", r);
  }

  // --- The end bosses' figure ------------------------------------------------------------------------------------
  // A chunky figure standing in the middle, as a kid would draw a boss: a big head, a body (or a robe), arms down
  // to the sides, a weapon in its right hand. o: { x, top, h, skin, body, legs, trim, robe, cape, wings, tail, horns,
  // hat, hair, beard, eyes, glow, ears, tusks, snout, mask, weapon, weaponCol, book, skullHead, stone, spikes }.
  function figure(c, r, o) {
    const x = o.x ?? 512, top = o.top ?? 34, ht = o.h ?? 470, u = ht / 10, foot = top + ht;
    const hx = x, hy = top + 1.7 * u, hr = 1.45 * u;
    const wideness = o.wide ?? 1;
    if (o.wings) {
      for (const s of [-1, 1]) {
        fill(c, [[x + s * 1.2 * u, top + 3.4 * u], [x + s * 5 * u, top + 0.4 * u], [x + s * 4.4 * u, top + 2.6 * u],
          [x + s * 5.3 * u, top + 3.4 * u], [x + s * 4.2 * u, top + 4.4 * u], [x + s * 4.6 * u, top + 5.4 * u], [x + s * 1.4 * u, top + 5.6 * u]], o.wings, r);
      }
    }
    if (o.tail) line(c, curve([[x + 1 * u, top + 6.4 * u], [x + 3.6 * u, top + 8 * u], [x + 4.6 * u, top + 6 * u]], 10), 0.9 * u, o.tail, r);
    if (o.spikes) {
      for (let i = 0; i < 7; i++) {
        const a = Math.PI * (1.1 + i * 0.13);
        const bx = x + Math.cos(a) * 2 * u, by = top + 4 * u + Math.sin(a) * 2 * u;
        fill(c, [[bx - 0.3 * u, by], [x + Math.cos(a) * 3.4 * u, top + 4 * u + Math.sin(a) * 3.4 * u], [bx + 0.3 * u, by]], o.spikes, r, { line: 8 });
      }
    }
    if (o.cape) fill(c, [[x - 1.7 * u, top + 3.2 * u], [x + 1.7 * u, top + 3.2 * u], [x + 2.7 * u, foot - 0.3 * u], [x - 2.7 * u, foot - 0.3 * u]], o.cape, r);
    if (o.robe) {
      fill(c, [[x - 1.5 * u * wideness, top + 3.2 * u], [x + 1.5 * u * wideness, top + 3.2 * u], [x + 2.4 * u * wideness, foot], [x - 2.4 * u * wideness, foot]], o.body, r);
      if (o.trim) fill(c, rect(x - 0.3 * u, top + 3.3 * u, x + 0.3 * u, foot - 0.1 * u), o.trim, r, { outline: null });
    } else {
      for (const s of [-1, 1]) {
        fill(c, rect(x + s * 0.85 * u * wideness - 0.6 * u, top + 6.2 * u, x + s * 0.85 * u * wideness + 0.6 * u, foot - 0.3 * u), o.legs || o.body, r);
        fill(c, ellipse(x + s * 0.95 * u * wideness, foot - 0.3 * u, 0.85 * u, 0.4 * u), o.boots || "#3a2414", r, { line: 10 });
      }
    }
    fill(c, [[x - 1.65 * u * wideness, top + 3.1 * u], [x + 1.65 * u * wideness, top + 3.1 * u], [x + 1.45 * u * wideness, top + 6.6 * u], [x - 1.45 * u * wideness, top + 6.6 * u]], o.body, r);
    if (o.trim && !o.robe) fill(c, rect(x - 1.5 * u * wideness, top + 5.9 * u, x + 1.5 * u * wideness, top + 6.4 * u), o.trim, r, { line: 8 });
    for (const s of [-1, 1]) {
      const sx = x + s * 1.5 * u * wideness;
      fill(c, [[sx - s * 0.3 * u, top + 3.15 * u], [sx + s * 0.5 * u, top + 3.15 * u], [sx + s * 1.5 * u, top + 5.5 * u], [sx + s * 0.8 * u, top + 5.9 * u]], o.arms || o.body, r);
      fill(c, circle(sx + s * 1.15 * u, top + 5.85 * u, 0.5 * u), o.hands || o.skin, r, { line: 10 });
    }
    const hand = [x + (1.5 * wideness + 1.15) * u, top + 5.85 * u], off = [x - (1.5 * wideness + 1.15) * u, top + 5.85 * u];
    // The head (and what goes behind it).
    if (o.horns) for (const s of [-1, 1]) fill(c, curve([[hx + s * 0.8 * u, hy - 0.9 * u], [hx + s * 2.2 * u, hy - 2.2 * u], [hx + s * 1.4 * u, hy - 3.1 * u], [hx + s * 0.4 * u, hy - 1.2 * u]], 8), o.horns, r);
    if (o.hat === "hood") fill(c, circle(hx, hy - 0.1 * u, hr * 1.3), o.hood || o.body, r);
    if (o.ears === "elf") for (const s of [-1, 1]) fill(c, [[hx + s * 1.1 * u, hy - 0.3 * u], [hx + s * 2.6 * u, hy - 1.2 * u], [hx + s * 1.2 * u, hy + 0.5 * u]], o.skin, r, { line: 10 });
    if (o.ears === "troll") for (const s of [-1, 1]) fill(c, [[hx + s * 1.1 * u, hy - 0.2 * u], [hx + s * 3 * u, hy - 0.6 * u], [hx + s * 1.2 * u, hy + 0.6 * u]], o.skin, r, { line: 10 });
    fill(c, circle(hx, hy, hr * (o.hat === "hood" ? 0.85 : 1)), o.skin, r);
    if (o.hair) fill(c, [...circle(hx, hy, hr * 1.04).filter(([, y]) => y <= hy - 0.2 * u)], o.hair, r, { line: 10 });
    if (o.longHair) for (const s of [-1, 1]) fill(c, rect(hx + s * 1.1 * u - 0.4 * u, hy - 0.4 * u, hx + s * 1.1 * u + 0.4 * u, hy + 2.6 * u), o.longHair, r, { line: 10 });
    if (o.mask) fill(c, rect(hx - hr * 0.95, hy + 0.15 * u, hx + hr * 0.95, hy + 1 * u), o.mask, r, { line: 10 });
    if (o.beard) fill(c, [[hx - 1.1 * u, hy + 0.35 * u], [hx + 1.1 * u, hy + 0.35 * u], [hx + 0.4 * u, hy + 2.6 * u], [hx - 0.4 * u, hy + 2.6 * u]], o.beard, r);
    if (o.snout) {
      fill(c, ellipse(hx, hy + 0.5 * u, 0.7 * u, 0.5 * u), o.snout, r, { line: 10 });
      dab(c, hx - 0.22 * u, hy + 0.5 * u, 0.12 * u, OUTLINE, 0.95);
      dab(c, hx + 0.22 * u, hy + 0.5 * u, 0.12 * u, OUTLINE, 0.95);
    }
    if (o.skullHead) {
      dab(c, hx - 0.5 * u, hy - 0.1 * u, 0.42 * u, OUTLINE, 0.95);
      dab(c, hx + 0.5 * u, hy - 0.1 * u, 0.42 * u, OUTLINE, 0.95);
      for (let i = -2; i <= 2; i++) line(c, [[hx + i * 0.25 * u, hy + 0.7 * u], [hx + i * 0.25 * u, hy + 1.1 * u]], 5, OUTLINE, r);
    }
    const eye = o.glow ? hex(o.glow) : OUTLINE;
    for (const s of [-1, 1]) {
      if (o.glow) dab(c, hx + s * 0.5 * u, hy - 0.1 * u, 0.3 * u, hex(o.glow), 0.5);
      if (!o.goggles) dab(c, hx + s * 0.5 * u, hy - 0.1 * u, 0.17 * u, eye, 0.95);
    }
    if (o.goggles) for (const s of [-1, 1]) fill(c, circle(hx + s * 0.55 * u, hy - 0.1 * u, 0.4 * u), o.goggles, r, { line: 10 });
    if (!o.mask && !o.beard && !o.snout && !o.skullHead) line(c, curve([[hx - 0.5 * u, hy + 0.75 * u], [hx, hy + 0.55 * u], [hx + 0.5 * u, hy + 0.75 * u]], 6), 8, OUTLINE, r);
    if (o.tusks) for (const s of [-1, 1]) fill(c, [[hx + s * 0.45 * u, hy + 0.85 * u], [hx + s * 0.7 * u, hy - 0.05 * u], [hx + s * 0.75 * u, hy + 0.85 * u]], "#f4f0e0", r, { line: 6 });
    // Hats.
    if (o.hat === "crown") fill(c, [[hx - 1.2 * u, hy - 1 * u], [hx - 1.2 * u, hy - 2.1 * u], [hx - 0.6 * u, hy - 1.5 * u], [hx, hy - 2.4 * u], [hx + 0.6 * u, hy - 1.5 * u], [hx + 1.2 * u, hy - 2.1 * u], [hx + 1.2 * u, hy - 1 * u]], o.crown || "#ffd23f", r);
    if (o.hat === "helmet") {
      fill(c, circle(hx, hy - 0.2 * u, hr * 1.05).filter(([, y]) => y <= hy - 0.2 * u), o.helmet || "#9aa0a8", r);
      fill(c, rect(hx - 0.15 * u, hy - 0.4 * u, hx + 0.15 * u, hy + 0.5 * u), o.helmet || "#9aa0a8", r, { line: 8 });
    }
    if (o.hat === "mohawk") fill(c, [[hx - 0.4 * u, hy - 1.2 * u], [hx - 0.2 * u, hy - 2.8 * u], [hx + 0.4 * u, hy - 2.5 * u], [hx + 0.4 * u, hy - 1.2 * u]], o.hairCol || "#ff4a3a", r);
    if (o.hat === "antlers") for (const s of [-1, 1]) {
      const b = [[hx + s * 0.6 * u, hy - 1.2 * u], [hx + s * 1.8 * u, hy - 2.6 * u], [hx + s * 2.6 * u, hy - 3.2 * u]];
      line(c, b, 0.35 * u, o.antlers || "#8a6a4a", r);
      line(c, [b[1], [hx + s * 1.4 * u, hy - 3.4 * u]], 0.3 * u, o.antlers || "#8a6a4a", r);
      line(c, [[hx + s * 2.2 * u, hy - 2.9 * u], [hx + s * 3.3 * u, hy - 2.6 * u]], 0.3 * u, o.antlers || "#8a6a4a", r);
    }
    if (o.hat === "bandana") fill(c, circle(hx, hy, hr * 1.04).filter(([, y]) => y <= hy - 0.5 * u), o.bandana || "#c02a2a", r, { line: 10 });
    if (o.leaves) for (let i = -2; i <= 2; i++) fill(c, ellipse(hx + i * 0.6 * u, hy - 1.5 * u + Math.abs(i) * 0.2 * u, 0.35 * u, 0.6 * u), o.leaves, r, { line: 8 });
    // The weapon in the right hand, and a book in the left.
    const [wx, wy] = hand, wc = o.weaponCol || "#c0c8d0";
    if (o.weapon === "sword" || o.weapon === "swords") {
      const swords = o.weapon === "swords" ? [hand, off] : [hand];
      for (const [sx, sy] of swords) {
        fill(c, [[sx - 0.22 * u, sy], [sx - 0.22 * u, sy - 3.6 * u], [sx, sy - 4.1 * u], [sx + 0.22 * u, sy - 3.6 * u], [sx + 0.22 * u, sy]], wc, r, { line: 10 });
        fill(c, rect(sx - 0.7 * u, sy - 0.2 * u, sx + 0.7 * u, sy + 0.1 * u), "#d0a040", r, { line: 8 });
      }
    }
    if (o.weapon === "staff") {
      line(c, [[wx, foot], [wx, top + 1 * u]], 0.3 * u, "#8a5a30", r);
      fill(c, circle(wx, top + 0.8 * u, 0.6 * u), wc, r, { line: 10 });
    }
    if (o.weapon === "skullstaff") {
      line(c, [[wx, foot], [wx, top + 1.2 * u]], 0.3 * u, "#3a3236", r);
      skull(c, r, wx, top + 0.8 * u, 0.5 * u);
    }
    if (o.weapon === "axe" || o.weapon === "bigaxe") {
      const big = o.weapon === "bigaxe" ? 1.5 : 1;
      line(c, [[wx, wy + 1.2 * u], [wx, wy - 3.6 * u]], 0.3 * u, "#6a4020", r);
      fill(c, [...curve([[wx, wy - 3.4 * u], [wx + 1.6 * big * u, wy - 3.9 * u], [wx + 1.4 * big * u, wy - 2.1 * u]], 8), [wx, wy - 2.5 * u]], wc, r);
      if (big > 1) fill(c, [...curve([[wx, wy - 3.4 * u], [wx - 1.6 * big * u, wy - 3.9 * u], [wx - 1.4 * big * u, wy - 2.1 * u]], 8), [wx, wy - 2.5 * u]], wc, r);
    }
    if (o.weapon === "hammer") {
      line(c, [[wx, wy + 1 * u], [wx, wy - 3.2 * u]], 0.3 * u, "#6a4020", r);
      fill(c, rect(wx - 0.9 * u, wy - 3.9 * u, wx + 0.9 * u, wy - 2.7 * u), wc, r);
    }
    if (o.weapon === "club") fill(c, rotate(ellipse(wx + 0.3 * u, wy - 1.8 * u, 0.6 * u, 1.9 * u), 0.2, wx, wy), "#8a5a2e", r);
    if (o.weapon === "wrench") {
      line(c, [[wx, wy + 0.5 * u], [wx + 0.6 * u, wy - 2.6 * u]], 0.4 * u, "#c0c8d0", r);
      fill(c, circle(wx + 0.7 * u, wy - 2.9 * u, 0.6 * u), "#c0c8d0", r, { holes: [circle(wx + 0.8 * u, wy - 3.1 * u, 0.25 * u)] });
    }
    if (o.weapon === "runeblade") {
      fill(c, [[wx - 0.3 * u, wy], [wx - 0.3 * u, wy - 4.2 * u], [wx, wy - 4.8 * u], [wx + 0.3 * u, wy - 4.2 * u], [wx + 0.3 * u, wy]], "#7ad8ff", r, { line: 10 });
      fill(c, rect(wx - 0.9 * u, wy - 0.2 * u, wx + 0.9 * u, wy + 0.15 * u), "#3a3236", r, { line: 8 });
    }
    if (o.book) fill(c, rotate(rect(off[0] - 0.8 * u, off[1] - 0.5 * u, off[0] + 0.8 * u, off[1] + 0.6 * u), -0.2, off[0], off[1]), o.book, r);
    if (o.orb) {
      soft(c, circle(off[0], off[1] - 0.9 * u, 0.9 * u), o.orb, r);
      fill(c, circle(off[0], off[1] - 0.9 * u, 0.5 * u), o.orb, r, { line: 8 });
    }
    if (o.runes) for (let i = 0; i < 5; i++) dab(c, x - 1 * u + i * 0.5 * u, top + 4.6 * u + (i % 2) * 0.5 * u, 0.15 * u, hex(o.runes), 0.95);
  }
  // A dragon facing left (Onyxia, the Shade of Eranikus): body, a curving neck, a horned head, wings, a tail.
  function dragon(c, r, o) {
    const col = o.col, belly = o.belly;
    fill(c, [[600, 210], [900, 30], [860, 180], [980, 170], [830, 330]], o.wing || col, r);  // back wing
    line(c, curve([[640, 400], [860, 470], [990, 380], [1010, 300]], 12), 46, col, r);  // the tail
    fill(c, ellipse(600, 360, 210, 110), col, r);
    soft(c, ellipse(590, 400, 150, 50), belly, r);
    for (const lx of [480, 700]) fill(c, rect(lx - 26, 400, lx + 26, 500), col, r);
    line(c, curve([[470, 320], [380, 260], [360, 170]], 10), 70, col, r);  // the neck
    fill(c, [[300, 120], [430, 110], [440, 200], [330, 230], [220, 210], [220, 170]], col, r);  // the head
    for (const hx of [380, 420]) fill(c, [[hx - 12, 118], [hx + 40, 30], [hx + 20, 120]], o.horns || "#f0e0c0", r, { line: 8 });
    dab(c, 330, 160, 13, hex(o.eye || "#ffd23f"), 0.95);
    line(c, [[230, 200], [320, 200]], 8, OUTLINE, r);
    fill(c, [[460, 260], [300, 60], [360, 230], [250, 220], [480, 330]], o.wing || col, r);  // front wing
    if (o.fire) for (let i = 0; i < 4; i++) flame(c, r, 170 - i * 30, 230 + i * 30, 40, 70);
  }

  // --- The dungeons ------------------------------------------------------------------------------------------------
  const DUNGEONS = {
    RFC(c, r) {  // Ragefire Chasm: a lava cave under Orgrimmar
      wall(c, r, "#3a1a14");
      fill(c, [[-20, 0], [W + 20, 0], [W + 20, 120], [700, 180], [512, 140], [300, 190], [-20, 130]], "#2a1210", r);
      lava(c, r, 330);
      for (const [x, ht] of [[230, 260], [512, 300], [800, 240]]) fill(c, [[x - 70, 340], [x - 20, 340 - ht], [x + 30, 340 - ht * 0.8], [x + 80, 340]], "#4a2a1a", r);
      for (let i = 0; i < 6; i++) flame(c, r, 180 + i * 130, 345, 26, 50 + (i % 2) * 30);
      banner(c, r, 512, 60, 90, 120, "#c02a2a", "#2a1a10");
    },
    WC(c, r) {  // Wailing Caverns: green mist, ferns, a pool
      wall(c, r, "#1e3a32");
      fill(c, ellipse(512, 120, 420, 160), "#2a5a48", r, { outline: null });
      water(c, r, 380, "#2a7a6a", "#8ae0c8");
      for (const x of [150, 330, 700, 880]) {
        for (let k = -2; k <= 2; k++) line(c, curve([[x, 390], [x + k * 30, 300], [x + k * 60, 260]], 8), 14, "#5bd24a", r);
      }
      for (let i = 0; i < 8; i++) soft(c, ellipse(150 + i * 110, 220 + (i % 3) * 30, 70, 20), "#6a9a88", r);
      fill(c, circle(512, 300, 50), "#b07aff", r);  // a big dreamy flower
      for (let i = 0; i < 6; i++) { const a = (i / 6) * 2 * Math.PI; fill(c, circle(512 + Math.cos(a) * 50, 300 + Math.sin(a) * 50, 30), "#e07ad8", r); }
      fill(c, circle(512, 300, 26), "#ffd23f", r);
    },
    DM(c, r) {  // The Deadmines: mine beams, a cart, the pirate ship in the cave
      wall(c, r, "#2a2018");
      fill(c, ellipse(512, 260, 300, 200), "#3a3040", r, { outline: null });
      fill(c, [[300, 330], [720, 330], [680, 400], [340, 400]], "#6a4020", r);  // the ship
      line(c, [[512, 330], [512, 90]], 16, "#4a3018", r);
      fill(c, [[520, 100], [660, 150], [520, 220]], "#f0e0b0", r);
      fill(c, rect(500, 70, 560, 100), "#c02a2a", r, { line: 8 });
      for (const x of [140, 884]) {
        line(c, [[x, 470], [x, 80]], 34, "#6a4020", r);
      }
      line(c, [[100, 90], [924, 90]], 34, "#6a4020", r);
      floor(c, r, 440, "#3a3028");
      line(c, [[-20, 470], [W + 20, 470]], 8, "#9aa0a8", r);
      fill(c, [[180, 400], [300, 400], [290, 460], [190, 460]], "#5a5f66", r);  // the cart, full of gold
      fill(c, ellipse(240, 400, 50, 20), "#ffd23f", r);
    },
    SFK(c, r) {  // Shadowfang Keep: the keep on its hill at night, a wolf howling
      bands(c, r, ["#1c1c3a", "#2a2448", "#3a2c50"]);
      moon(c, r, 760, 110, 60);
      stars(c, r, 30);
      ground(c, r, 400, "#2a3028", 40, 1.5);
      castle(c, r, 470, 400, 360, 300, "#5a5a68", "#3a3a4e");
      fill(c, [[780, 420], [800, 330], [830, 300], [850, 260], [870, 300], [880, 360], [900, 420]], "#3a3a44", r);  // the wolf
      fill(c, [[850, 262], [880, 220], [868, 268]], "#3a3a44", r, { line: 8 });
    },
    BFD(c, r) {  // Blackfathom Deeps: sunken night elf ruins, deep blue water
      bands(c, r, ["#0e2a44", "#14365a", "#1a4470"]);
      for (const x of [220, 400, 620, 800]) pillar(c, r, x, 140 + (x % 3) * 20, 440, 60, "#5a7a8a", "#7a9aaa");
      fill(c, rect(160, 110, 460, 140), "#7a9aaa", r);
      for (let i = 0; i < 25; i++) fill(c, circle(150 + r() * 720, 40 + r() * 380, 5 + r() * 9), "#9fe8ff", r, { line: 4 });
      floor(c, r, 450, "#1a2a3a");
      fill(c, circle(512, 300, 46), "#9fe8ff", r);  // a moonwell glow
      soft(c, circle(512, 300, 90), "#5aa8d8", r);
    },
    STOCKS(c, r) {  // The Stockade: cells in Stormwind's prison
      wall(c, r, "#4a4a52");
      for (let y = 40; y < 440; y += 60) for (let x = (y / 60) % 2 ? 0 : 50; x < W; x += 100) fill(c, rect(x, y, x + 96, y + 56), "#5a5a62", r, { line: 6, hatch: 18 });
      fill(c, rect(230, 120, 794, 440), "#1a1418", r);
      bars(c, r, 240, 784, 120, 440, 9);
      for (const x of [140, 884]) torch(c, r, x, 330);
      floor(c, r, 440, "#3a3236");
      fill(c, ellipse(420, 380, 60, 30), "#c02a2a", r);  // a defias mask in the cell
    },
    GNOMER(c, r) {  // Gnomeregan: gears, pipes, green radiation
      wall(c, r, "#24303a");
      soft(c, ellipse(512, 400, 500, 160), "#3a6a2a", r);
      for (const y of [80, 160]) line(c, [[-20, y], [W + 20, y]], 30, "#7a8088", r);
      gear(c, r, 300, 260, 110, 10, "#a0a8b0");
      gear(c, r, 470, 180, 70, 8, "#d0a040");
      gear(c, r, 720, 280, 130, 12, "#8a9098");
      floor(c, r, 430, "#2a3a2a");
      for (let i = 0; i < 6; i++) fill(c, ellipse(150 + i * 140, 440, 50, 14), "#7aff4a", r, { line: 6 });
      mech(c, r, 880, 430);
    },
    RFK(c, r) {  // Razorfen Kraul: thorny brambles, quilboar huts
      bands(c, r, ["#a05a3a", "#c07a4a", "#d89a5a"]);
      ground(c, r, 380, "#8a5a30", 20, 2);
      hut(c, r, 300, 400, 160, "#a07040", "#6a4020");
      hut(c, r, 700, 410, 200, "#a07040", "#5a3a1a");
      thorns(c, r, 300);
    },
    SMGY(c, r) {  // Scarlet Monastery: Graveyard
      bands(c, r, ["#2a1c2c", "#3a2434", "#4a2c3a"]);
      moon(c, r, 200, 100, 46, "#e8e0d0");
      castle(c, r, 720, 330, 300, 260, "#6a5a5a", "#a02a2a", "#ffcc55");
      ground(c, r, 380, "#2a3024", 14, 3);
      for (const [x, s] of [[200, 1], [330, 1.2], [470, 0.9], [600, 1.1], [880, 1]]) tomb(c, r, x, 430, 70 * s, 110 * s);
      dots(c, r, 20, "#9fe8c0", 6, [100, 250, 900, 420]);
    },
    SMLIB(c, r) {  // Scarlet Monastery: Library
      wall(c, r, "#4a2a24");
      const books = ["#c02a2a", "#4f86e8", "#5bd24a", "#ffd23f", "#8a5a2e", "#e07ad8"];
      for (const y of [140, 260, 380]) shelf(c, r, -10, 380, y, books), shelf(c, r, 644, W + 10, y, books);
      banner(c, r, 512, 40, 140, 260, "#c02a2a", "#ffd23f");
      floor(c, r, 430, "#5a3a2a");
      fill(c, rect(430, 360, 594, 440), "#6a4020", r);  // a reading desk with an open book
      fill(c, [[452, 350], [512, 340], [572, 350], [572, 372], [452, 372]], "#f0e0b0", r, { line: 8 });
    },
    SMARM(c, r) {  // Scarlet Monastery: Armory
      wall(c, r, "#4a3a34");
      for (const x of [230, 512, 794]) weaponRack(c, r, x, 430);
      for (const x of [370, 650]) shield(c, r, x, 150, 60, "#c02a2a", "#ffd23f");
      floor(c, r, 430, "#5a4a40");
    },
    SMCATH(c, r) {  // Scarlet Monastery: Cathedral
      wall(c, r, "#3a2a34");
      window(c, r, 512, 30, 260, 330, ["#c02a2a", "#ffd23f", "#4f86e8"]);
      for (const x of [200, 824]) pillar(c, r, x, 80, 440, 70, "#8a7a7a", "#a09090");
      floor(c, r, 440, "#5a4a4a");
      fill(c, [[440, 440], [584, 440], [700, H + 20], [324, H + 20]], "#c02a2a", r);  // the red carpet
    },
    RFD(c, r) {  // Razorfen Downs: icy thorns and bones
      bands(c, r, ["#2a3448", "#3a4a64", "#4a5a78"]);
      ground(c, r, 380, "#5a6070", 18, 2);
      thorns(c, r, 300, "#3a3a4a", "#c8e8ff");
      for (const [x, y] of [[300, 440], [700, 450]]) skull(c, r, x, y, 26);
      bone(c, r, 420, 460, 540, 430);
      dots(c, r, 30, "#e8f4ff", 4, [0, 0, W, 300]);
    },
    ULDA(c, r) {  // Uldaman: titan halls, a glowing disc, stone keepers
      wall(c, r, "#4a4038");
      for (let y = 30; y < 430; y += 80) line(c, [[-20, y], [W + 20, y]], 6, "#3a3028", r);
      fill(c, circle(512, 220, 120), "#7a6a58", r, { holes: [circle(512, 220, 70)] });
      soft(c, circle(512, 220, 70), "#5ac8ff", r);
      for (const x of [220, 804]) figure(c, r, { x, top: 130, h: 310, skin: "#8a8078", body: "#8a8078", glow: "#5ac8ff", stone: true });
      floor(c, r, 440, "#5a5048");
    },
    ZF(c, r) {  // Zul'Farrak: a sandy troll city, its steps, the sun
      bands(c, r, ["#f0b060", "#f8c878", "#ffe0a0"]);
      fill(c, circle(820, 100, 54), "#ffd23f", r);
      ground(c, r, 400, "#e8c080", 16, 3);
      for (let i = 0; i < 4; i++) fill(c, rect(330 + i * 40, 160 + i * 60, 694 - i * 40, 220 + i * 60), i % 2 ? "#c8945a" : "#b8844a", r);
      fill(c, rect(470, 100, 554, 160), "#a8743a", r);
      for (const x of [180, 860]) {
        line(c, [[x, 420], [x, 230]], 22, "#8a5a30", r);
        skull(c, r, x, 210, 26);
      }
    },
    MARA(c, r) {  // Maraudon: purple crystals and a waterfall
      wall(c, r, "#2a1a3a");
      fill(c, rect(440, -20, 584, 400), "#6ab0e0", r);
      for (let i = 0; i < 5; i++) line(c, [[460 + i * 28, 0], [460 + i * 28, 390]], 4, "#c8ecff", r);
      water(c, r, 400, "#4a8ac0", "#c8ecff");
      for (const [x, ht] of [[180, 220], [260, 150], [330, 260], [700, 240], [780, 170], [860, 280]]) crystal(c, r, x, 420, ht, x % 2 ? "#b07aff" : "#e07ad8");
      dots(c, r, 20, "#e8c8ff", 5, [100, 50, 900, 300]);
    },
    ST(c, r) {  // The Temple of Atal'Hakkar: a sunken temple in the swamp
      bands(c, r, ["#2a3a2a", "#3a4a32", "#4a5a3a"]);
      for (let i = 0; i < 4; i++) fill(c, rect(300 + i * 50, 140 + i * 50, 724 - i * 50, 190 + i * 50), i % 2 ? "#6a7a5a" : "#5a6a4a", r);
      fill(c, rect(470, 90, 554, 140), "#4a5a3a", r);
      water(c, r, 360, "#3a5a3a", "#7aa86a");
      for (const x of [140, 880]) tree(c, r, x, 380, 260, "#3a6a2a", "#4a3a1e");
      for (const x of [260, 764]) line(c, curve([[x, 0], [x + 20, 120], [x - 10, 220]], 8), 10, "#3f8f3a", r);  // vines
    },
    BRD(c, r) {  // Blackrock Depths: the Dark Iron city, forges and lava
      wall(c, r, "#2a1c18");
      lava(c, r, 400);
      for (const [x, ht] of [[160, 260], [360, 320], [664, 340], [864, 270]]) {
        fill(c, rect(x - 60, 400 - ht, x + 60, 400), "#3a3030", r);
        fill(c, rect(x - 20, 400 - ht + 40, x + 20, 400 - ht + 80), "#ffb040", r, { line: 8 });
      }
      fill(c, [[430, 400], [460, 280], [512, 240], [564, 280], [594, 400]], "#4a3a34", r);  // the anvil throne
      fill(c, rect(470, 290, 554, 330), "#ffd23f", r, { line: 8 });
      for (let i = 0; i < 6; i++) sparkle(c, r, 200 + r() * 620, 60 + r() * 150, 10 + r() * 8, "#ff9a2a");
    },
    LBRS(c, r) {  // Lower Blackrock Spire: the black mountain, orc banners
      bands(c, r, ["#4a1a14", "#6a2a18", "#8a3a1c"]);
      fill(c, [[150, 470], [380, 120], [512, 20], [644, 120], [874, 470]], "#2a2228", r);
      lava(c, r, 430);
      for (const x of [380, 644]) banner(c, r, x, 160, 80, 150, "#3a3236", "#c02a2a");
      fill(c, rect(470, 300, 554, 430), "#120c10", r);
    },
    UBRS(c, r) {  // Upper Blackrock Spire: the dragon lair at the top, eggs
      bands(c, r, ["#3a1414", "#5a1c18", "#7a2a1c"]);
      fill(c, [[-20, 300], [300, 220], [724, 220], [W + 20, 300], [W + 20, H + 20], [-20, H + 20]], "#2a2228", r);
      for (const x of [200, 824]) pillar(c, r, x, 60, 300, 60, "#3a3236", "#4a4046");
      for (const [x, s] of [[360, 50], [450, 60], [560, 55], [660, 48], [410, 40], [610, 42]]) egg(c, r, x, 380 + (s % 3) * 20, s, "#5a3a5a");
      banner(c, r, 512, 50, 120, 180, "#2a2228", "#c02a2a");
    },
    DME(c, r) {  // Dire Maul: East, overgrown elven gardens
      bands(c, r, ["#3a5a3a", "#4a7048", "#5a8a58"]);
      for (const x of [260, 764]) pillar(c, r, x, 120, 430, 70, "#a0a0b8", "#c0c0d8");
      fill(c, rect(190, 90, 834, 124), "#c0c0d8", r);
      for (let i = 0; i < 9; i++) line(c, curve([[190 + i * 75, 124], [200 + i * 75, 200], [180 + i * 75, 260]], 8), 10, "#3f8f3a", r);
      ground(c, r, 430, "#3a6a2a", 10, 3);
      tree(c, r, 512, 440, 300, "#5bd24a", "#6a4a2a");
    },
    DMW(c, r) {  // Dire Maul: West, arcane pylons
      bands(c, r, ["#24203a", "#302a4e", "#3a3462"]);
      for (const x of [220, 804]) pillar(c, r, x, 100, 430, 60, "#8a88a8", "#a8a8c8");
      for (const x of [380, 644]) {
        fill(c, [[x - 30, 430], [x, 200], [x + 30, 430]], "#5a5a7a", r);
        soft(c, circle(x, 200, 50), "#7ad8ff", r);
        fill(c, circle(x, 200, 22), "#c8f0ff", r);
      }
      line(c, curve([[380, 200], [512, 120], [644, 200]], 12), 8, "#9fe8ff", r);
      floor(c, r, 430, "#2a2a3e");
    },
    DMN(c, r) {  // Dire Maul: North, the Gordok ogres' halls (the club's own kind)
      wall(c, r, "#5a4030");
      hut(c, r, 512, 430, 280, "#8a5a30", "#6a3a1a");
      for (const x of [170, 854]) { line(c, [[x, 430], [x, 200]], 26, "#6a4020", r); skull(c, r, x, 180, 34); }
      fill(c, rotate(ellipse(330, 400, 24, 80), 0.6, 330, 400), "#8a5a2e", r);  // a club, a mug
      fill(c, rect(680, 390, 730, 440), "#c8a060", r);
      fill(c, ellipse(705, 390, 28, 10), "#f8f0d0", r, { line: 6 });
      floor(c, r, 430, "#4a3020");
    },
    SCHOLO(c, r) {  // Scholomance: a dark classroom, a chalkboard, skulls
      wall(c, r, "#2a2430");
      fill(c, rect(250, 60, 774, 300), "#2a3a2a", r);  // the chalkboard
      line(c, curve([[300, 120], [380, 100], [460, 140], [540, 110]], 8), 6, "#f0f0e8", r);
      line(c, [[320, 200], [480, 200]], 6, "#f0f0e8", r);
      skull(c, r, 640, 180, 40, "#f0f0e8");
      shelf(c, r, -10, 220, 260, ["#5a2a6a", "#2a2a3a", "#6a4a2a"]);
      shelf(c, r, 804, W + 10, 260, ["#5a2a6a", "#2a2a3a", "#6a4a2a"]);
      floor(c, r, 410, "#3a3036");
      for (const x of [330, 512, 694]) fill(c, rect(x - 70, 400, x + 70, 440), "#6a4020", r);  // desks
      dots(c, r, 16, "#b07aff", 6, [100, 320, 900, 400]);
    },
    STRATL(c, r) {  // Stratholme: the living side, a burning city
      bands(c, r, ["#4a1a14", "#7a2a18", "#a04a20"]);
      for (const [x, ht] of [[180, 260], [380, 200], [640, 240], [860, 300]]) {
        fill(c, rect(x - 80, 430 - ht, x + 80, 430), "#5a4a44", r);
        fill(c, [[x - 95, 430 - ht], [x, 430 - ht - 80], [x + 95, 430 - ht]], "#3a2a2a", r);
        flame(c, r, x - 20, 430 - ht - 40, 40, 90);
      }
      floor(c, r, 430, "#4a3a34");
      banner(c, r, 512, 220, 70, 120, "#c02a2a", "#ffd23f");
    },
    STRATU(c, r) {  // Stratholme: the undead side, plague and a ziggurat
      bands(c, r, ["#1a2414", "#2a3a1c", "#3a4a24"]);
      for (let i = 0; i < 4; i++) fill(c, rect(320 + i * 45, 140 + i * 70, 704 - i * 45, 210 + i * 70).map(([x, y]) => [x, 560 - y]), "#4a4a3a", r);
      soft(c, ellipse(512, 420, 480, 90), "#6aaa3a", r);
      floor(c, r, 440, "#2a3020");
      for (let i = 0; i < 8; i++) fill(c, circle(150 + i * 105, 450 + (i % 2) * 14, 16), "#9aff5a", r, { line: 6 });
      dots(c, r, 30, "#b8ff8a", 5, [100, 50, 900, 380]);
    },
    THANES(c, r) {  // The Hall of Thanes (Forever): a dwarven stone hall
      wall(c, r, "#4a3a2e");
      for (const x of [160, 360, 664, 864]) pillar(c, r, x, 90, 430, 70, "#8a7a68", "#a89880");
      for (const x of [260, 764]) banner(c, r, x, 60, 90, 170, "#2a4a8a", "#ffd23f");
      fill(c, rect(430, 250, 594, 430), "#6a5a48", r);  // the thanes' throne
      fill(c, rect(450, 180, 574, 250), "#6a5a48", r);
      floor(c, r, 430, "#5a4a3a");
      fill(c, rotate(rect(480, 300, 544, 340), 0, 0, 0), "#9aa0a8", r, { line: 8 });
    },
    RUINS(c, r) {  // The Ruins of Lordaeron (Forever): the broken throne room, green plague light
      bands(c, r, ["#1e2a1e", "#2a3a28", "#3a4a34"]);
      for (const [x, ht] of [[180, 300], [340, 180], [690, 240], [850, 320]]) pillar(c, r, x, 430 - ht, 430, 60, "#8a8a80", "#a0a098");
      fill(c, [[300, 120], [420, 80], [380, 140]], "#8a8a80", r);
      fill(c, rect(450, 280, 574, 430), "#5a5a58", r);  // the throne
      fill(c, rect(470, 200, 554, 280), "#5a5a58", r);
      for (let i = 0; i < 18; i++) {
        const a = (i / 18) * 2 * Math.PI;
        dab(c, 512 + Math.cos(a) * 120, 260 + Math.sin(a) * 100, 8, hex("#7ad86a"), 0.9);
      }
      floor(c, r, 430, "#3a3a34");
      fill(c, rect(470, 430, 554, H + 20), "#8a2a2a", r);
    },
    EXCAV(c, r) {  // Excavation Site: Wetlands (Forever): a dig in the rain
      bands(c, r, ["#5a6a70", "#6a7a7a", "#7a8a84"]);
      ground(c, r, 360, "#5a4a2a", 18, 2);
      fill(c, ellipse(512, 430, 260, 80), "#3a2a18", r);  // the dig
      fill(c, [[180, 360], [260, 220], [340, 360]], "#d8c8a0", r);  // a tent
      fill(c, rect(700, 280, 820, 360), "#8a5a30", r);  // crates
      fill(c, rect(730, 240, 800, 280), "#a06a38", r);
      fill(c, circle(512, 410, 40), "#8a8078", r);  // a relic coming up
      soft(c, circle(512, 410, 70), "#5ac8ff", r);
      for (let i = 0; i < 40; i++) { const x = r() * W, y = r() * 300; line(c, [[x, y], [x - 8, y + 26]], 3, "#c8e0f0", r); }
    },
    ONY(c, r) {  // Onyxia's Lair: a lava cave, eggs, bones and gold
      wall(c, r, "#2a1814");
      fill(c, ellipse(512, 220, 420, 200), "#3a2420", r, { outline: null });
      lava(c, r, 430);
      for (const [x, s] of [[200, 50], [270, 44], [760, 52], [830, 46]]) egg(c, r, x, 400, s, "#3a2a3a");
      fill(c, [[380, 430], ...curve([[380, 430], [512, 360], [644, 430]], 10)], "#ffd23f", r);
      bone(c, r, 420, 450, 520, 420);
      skull(c, r, 600, 430, 22);
      dab(c, 470, 160, 14, hex("#ffd23f"), 0.95);  // eyes in the dark
      dab(c, 554, 160, 14, hex("#ffd23f"), 0.95);
    },
    BARROW(c, r) {  // Barrow Deeps (Forever): grassy barrow mounds, moonlight and mist
      bands(c, r, ["#1c1a34", "#2a2444", "#3a2c50"]);
      moon(c, r, 512, 100, 56, "#e8e0ff");
      stars(c, r, 30);
      for (const [x, w] of [[220, 240], [800, 280]]) fill(c, ellipse(x, 430, w, 160).filter(([, y]) => y <= 430), "#2a4a2a", r);
      fill(c, ellipse(512, 440, 220, 200).filter(([, y]) => y <= 440), "#3a5a32", r);
      fill(c, ellipse(512, 440, 60, 90).filter(([, y]) => y <= 440), "#100c14", r);  // the barrow's door
      for (const x of [440, 584]) fill(c, rect(x - 18, 300, x + 18, 440), "#8a8890", r);
      floor(c, r, 440, "#1e2a1e");
      for (let i = 0; i < 6; i++) soft(c, ellipse(120 + i * 160, 450, 120, 24), "#8a7ab0", r);
    },
    HYJAL(c, r) {  // Hyjal Summit: the World Tree over the mountain at night
      bands(c, r, ["#141a34", "#1c2a48", "#24385a"]);
      stars(c, r, 50, 300);
      ground(c, r, 420, "#2a4a3a", 30, 1.5);
      line(c, curve([[512, 440], [500, 300], [530, 160]], 10), 90, "#6a5a4a", r);  // Nordrassil
      for (const [x, y, s] of [[512, 110, 170], [380, 170, 120], [650, 170, 120], [450, 60, 100], [580, 60, 100]]) fill(c, circle(x, y, s), "#3a8a5a", r);
      for (let i = 0; i < 14; i++) sparkle(c, r, 260 + r() * 500, 30 + r() * 240, 8 + r() * 6, "#c8ffe0");
      for (const x of [150, 880]) pine(c, r, x, 440, 220, "#1f3a2a");
    },
  };

  // --- The end bosses (in front of a bit of their dungeon) -------------------------------------------------------
  const scene = (key) => (c, r) => DUNGEONS[key](c, r);
  const dim = (c, r) => soft(c, rect(-20, -20, W + 20, H + 20), "#000000", r, { hatch: 40 });
  const behind = (key) => (c, r) => { DUNGEONS[key](c, r); dim(c, r); };
  const BOSSES = {
    RFC: (c, r) => { behind("RFC")(c, r);  // Bazzalan, a satyr
      figure(c, r, { skin: "#8a5ab0", body: "#5a3a7a", legs: "#6a4a2a", boots: "#2a1a10", horns: "#e0d0b0", glow: "#7aff4a", weapon: "sword", weaponCol: "#7aff4a" }); },
    WC: (c, r) => { behind("WC")(c, r);  // Mutanus the Devourer, a giant murloc
      fill(c, ellipse(512, 300, 220, 200), "#4aa86a", r);
      soft(c, ellipse(512, 350, 150, 110), "#bfe8a8", r);
      fill(c, [[400, 110], [512, 30], [624, 110]], "#e07a5a", r);  // the fin
      for (const s of [-1, 1]) dab(c, 512 + s * 80, 220, 28, hex("#ffffff"), 0.95), dab(c, 512 + s * 80, 220, 14, OUTLINE, 0.95);
      fill(c, ellipse(512, 300, 120, 40), "#2a1414", r);  // the big mouth
      for (let i = -3; i <= 3; i++) fill(c, [[512 + i * 30 - 10, 268], [512 + i * 30, 292], [512 + i * 30 + 10, 268]], "#ffffff", r, { line: 4 });
      for (const s of [-1, 1]) fill(c, ellipse(512 + s * 230, 330, 50, 26), "#4aa86a", r), fill(c, ellipse(512 + s * 110, 490, 60, 30), "#3a8858", r); },
    DM: (c, r) => { behind("DM")(c, r);  // Edwin VanCleef
      figure(c, r, { skin: "#f0c8a0", body: "#6a4a2a", legs: "#4a3420", trim: "#2a1a10", cape: "#3a2a20", mask: "#c02a2a", hat: "bandana", bandana: "#3a2a20", weapon: "swords" }); },
    SFK: (c, r) => { behind("SFK")(c, r);  // Archmage Arugal
      figure(c, r, { skin: "#a8b0a0", body: "#5a2a7a", trim: "#ffd23f", robe: true, hat: "hood", hood: "#4a1a6a", glow: "#e0e0ff", weapon: "staff", weaponCol: "#b07aff", orb: "#b07aff" }); },
    BFD: (c, r) => { behind("BFD")(c, r);  // Aku'mai, a three-headed hydra
      fill(c, ellipse(512, 400, 260, 120), "#3a6a8a", r);
      fill(c, ellipse(512, 360, 220, 100), "#2a4a3a", r);  // the shell
      for (let i = 0; i < 5; i++) fill(c, circle(400 + i * 56, 350, 20), "#3a6a4a", r, { line: 6 });
      for (const [dx, ty] of [[-180, 120], [0, 60], [180, 120]]) {
        line(c, curve([[512 + dx * 0.5, 330], [512 + dx * 0.8, 220], [512 + dx, ty + 40]], 10), 46, "#3a7a9a", r);
        fill(c, ellipse(512 + dx, ty, 60, 40), "#3a7a9a", r);
        dab(c, 512 + dx - 20, ty - 10, 9, hex("#ffd23f"), 0.95);
        fill(c, [[512 + dx - 50, ty + 10], [512 + dx - 90, ty + 20], [512 + dx - 50, ty + 26]], "#ffffff", r, { line: 4 });
      } },
    STOCKS: (c, r) => { behind("STOCKS")(c, r);  // Bazil Thredd
      figure(c, r, { skin: "#f0c8a0", body: "#8a6a4a", legs: "#5a4a3a", trim: "#3a2a20", mask: "#c02a2a", hair: "#4a3020", weapon: "sword" }); },
    GNOMER: (c, r) => { behind("GNOMER")(c, r);  // Mekgineer Thermaplugg, in his walker
      fill(c, rect(330, 180, 694, 400), "#8a9098", r);
      for (const s of [-1, 1]) fill(c, rect(512 + s * 120 - 40, 400, 512 + s * 120 + 40, 500), "#6a7078", r), gear(c, r, 512 + s * 220, 300, 60, 8, "#d0a040");
      fill(c, rect(420, 220, 604, 330), "#3a4a3a", r);  // the cockpit
      figure(c, r, { x: 512, top: 60, h: 300, skin: "#f8d8b8", body: "#4f86e8", hair: "#ff7ab0", goggles: "#9fe8ff", weapon: "wrench" });
      soft(c, rect(420, 260, 604, 330), "#3a4a3a", r); },
    RFK: (c, r) => { behind("RFK")(c, r);  // Charlga Razorflank, a quilboar
      figure(c, r, { skin: "#c8907a", body: "#7a4a2a", legs: "#6a3a20", snout: "#e0a890", tusks: true, spikes: "#e8d8b0", weapon: "staff", weaponCol: "#7aff4a" }); },
    SMGY: (c, r) => { behind("SMGY")(c, r);  // Bloodmage Thalnos
      figure(c, r, { skin: "#e8e0d0", skullHead: true, body: "#8a1a1a", trim: "#ffd23f", robe: true, glow: "#ff4a3a", weapon: "skullstaff", orb: "#ff4a3a" }); },
    SMLIB: (c, r) => { behind("SMLIB")(c, r);  // Arcanist Doan
      figure(c, r, { skin: "#f0c8a0", body: "#c02a2a", trim: "#ffd23f", robe: true, beard: "#f0f0f0", hair: "#f0f0f0", book: "#4f86e8", weapon: "staff", weaponCol: "#b07aff" }); },
    SMARM: (c, r) => { behind("SMARM")(c, r);  // Herod
      figure(c, r, { skin: "#f0c8a0", body: "#c02a2a", legs: "#9a2020", arms: "#9aa0a8", trim: "#ffd23f", hat: "helmet", helmet: "#c02a2a", wide: 1.25, weapon: "bigaxe" }); },
    SMCATH: (c, r) => { behind("SMCATH")(c, r);  // High Inquisitor Whitemane
      figure(c, r, { skin: "#f8d8c0", body: "#c02a2a", trim: "#f8f0e0", robe: true, longHair: "#f8f8f8", hair: "#f8f8f8", weapon: "staff", weaponCol: "#ffd23f" }); },
    RFD: (c, r) => { behind("RFD")(c, r);  // Amnennar the Coldbringer, a quilboar lich
      figure(c, r, { skin: "#e8e8f0", skullHead: true, body: "#3a4a7a", trim: "#9fe8ff", robe: true, hat: "crown", crown: "#9fe8ff", glow: "#9fe8ff", weapon: "staff", weaponCol: "#9fe8ff", tusks: true }); },
    ULDA: (c, r) => { behind("ULDA")(c, r);  // Archaedas, a stone keeper
      figure(c, r, { skin: "#8a8078", body: "#7a7068", legs: "#6a6058", boots: "#5a5048", wide: 1.3, glow: "#5ac8ff", runes: "#5ac8ff", weapon: "hammer", weaponCol: "#8a8078", beard: "#6a6058" }); },
    ZF: (c, r) => { behind("ZF")(c, r);  // Chief Ukorz Sandscalp, a sand troll
      figure(c, r, { skin: "#c8a878", body: "#8a5a30", legs: "#6a4020", trim: "#e0c060", ears: "troll", tusks: true, hat: "mohawk", hairCol: "#e04a2a", weapon: "axe" }); },
    MARA: (c, r) => { behind("MARA")(c, r);  // Princess Theradras, of earth and crystals
      figure(c, r, { skin: "#8a6a5a", body: "#6a4a5a", robe: true, wide: 1.3, hat: "crown", crown: "#b07aff", longHair: "#b07aff", glow: "#e0c8ff" });
      for (const [x, ht] of [[300, 120], [720, 140]]) crystal(c, r, x, 500, ht, "#b07aff"); },
    ST: (c, r) => { behind("ST")(c, r);  // the Shade of Eranikus, a ghostly green dragon
      dragon(c, r, { col: "#5aa86a", belly: "#a8e8a0", wing: "#3a8a5a", eye: "#c8ffe0" });
      soft(c, rect(-20, -20, W + 20, H + 20), "#7ad86a", r, { hatch: 50 }); },
    BRD: (c, r) => { behind("BRD")(c, r);  // Emperor Dagran Thaurissan, a Dark Iron dwarf
      figure(c, r, { top: 90, h: 410, wide: 1.3, skin: "#6a7078", body: "#8a2a1a", legs: "#3a3236", trim: "#ffd23f", beard: "#2a2228", hat: "crown", glow: "#ff9a2a", weapon: "hammer", weaponCol: "#3a3236", cape: "#5a1a14" }); },
    LBRS: (c, r) => { behind("LBRS")(c, r);  // Overlord Wyrmthalak, a dragonspawn
      figure(c, r, { skin: "#3a3240", body: "#5a2a2a", legs: "#3a3240", horns: "#c8b8a0", wings: "#2a2228", tail: "#3a3240", glow: "#ff4a3a", weapon: "axe", wide: 1.2 }); },
    UBRS: (c, r) => { behind("UBRS")(c, r);  // General Drakkisath
      figure(c, r, { skin: "#2a2228", body: "#5a5f66", legs: "#2a2228", arms: "#5a5f66", trim: "#c02a2a", horns: "#e0d0b0", wings: "#3a1a1a", tail: "#2a2228", glow: "#ff4a3a", wide: 1.35, weapon: "bigaxe", weaponCol: "#8a9098" }); },
    DME: (c, r) => { behind("DME")(c, r);  // Alzzin the Wildshaper, a satyr
      figure(c, r, { skin: "#6a8a3a", body: "#3a5a2a", legs: "#5a3a1a", horns: "#d8c8a0", glow: "#c8ff5a", leaves: "#5bd24a", weapon: "staff", weaponCol: "#5bd24a" }); },
    DMW: (c, r) => { behind("DMW")(c, r);  // Prince Tortheldrin, a Highborne
      figure(c, r, { skin: "#b8a0e0", body: "#2a4a8a", trim: "#ffd23f", robe: true, ears: "elf", hat: "crown", longHair: "#e8e8ff", glow: "#9fe8ff", weapon: "sword", weaponCol: "#9fe8ff" }); },
    DMN: (c, r) => { behind("DMN")(c, r);  // King Gordok, an ogre king (a big one)
      figure(c, r, { top: 20, h: 480, wide: 1.5, skin: "#c89a6a", body: "#6a4a7a", legs: "#5a3a2a", trim: "#ffd23f", tusks: true, hat: "crown", weapon: "club" }); },
    SCHOLO: (c, r) => { behind("SCHOLO")(c, r);  // Darkmaster Gandling
      figure(c, r, { skin: "#d8c8b0", body: "#2a2228", trim: "#b07aff", robe: true, hat: "hood", hood: "#1a1418", glow: "#b07aff", weapon: "skullstaff", orb: "#b07aff" }); },
    STRATL: (c, r) => { behind("STRATL")(c, r);  // Balnazzar, a dreadlord
      figure(c, r, { skin: "#6a4a7a", body: "#3a2a4a", legs: "#2a1a34", horns: "#d8c8a0", wings: "#2a1a2a", ears: "elf", glow: "#7aff4a", weapon: "sword", weaponCol: "#7aff4a" }); },
    STRATU: (c, r) => { behind("STRATU")(c, r);  // Baron Rivendare, on his skeletal horse
      fill(c, ellipse(512, 380, 230, 80), "#e0dcd0", r);  // the horse
      for (const x of [340, 420, 610, 690]) fill(c, rect(x - 14, 400, x + 14, 500), "#e0dcd0", r);
      fill(c, [[280, 380], [200, 260], [160, 220], [230, 200], [320, 330]], "#e0dcd0", r);
      dab(c, 200, 230, 9, hex("#9fe8ff"), 0.95);
      figure(c, r, { x: 540, top: 30, h: 360, skin: "#c8d0d8", body: "#3a3a44", legs: "#2a2a34", arms: "#5a5f66", cape: "#1a1a24", hat: "helmet", helmet: "#3a3a44", glow: "#9fe8ff", weapon: "runeblade" }); },
    THANES: (c, r) => { behind("THANES")(c, r);  // Durgen Dirgehammer, a ghostly dwarf thane
      figure(c, r, { top: 90, h: 410, wide: 1.3, skin: "#a8c8d8", body: "#5a7a9a", legs: "#3a5a7a", trim: "#ffd23f", beard: "#e8f4ff", hat: "helmet", helmet: "#9aa0a8", glow: "#c8f0ff", weapon: "hammer" });
      soft(c, rect(-20, -20, W + 20, H + 20), "#9fe8ff", r, { hatch: 60 }); },
    RUINS: (c, r) => { behind("RUINS")(c, r);  // Rath'mael
      figure(c, r, { skin: "#9aa890", body: "#2a3a2a", trim: "#7ad86a", robe: true, hat: "hood", hood: "#1a2a1a", glow: "#7ad86a", weapon: "staff", weaponCol: "#7ad86a", orb: "#7ad86a" }); },
    EXCAV: (c, r) => { behind("EXCAV")(c, r);  // the Relic Guardian, a stone golem
      figure(c, r, { skin: "#8a8078", body: "#7a7068", legs: "#6a6058", arms: "#7a7068", hands: "#8a8078", boots: "#5a5048", wide: 1.4, glow: "#5ac8ff", runes: "#5ac8ff" }); },
    ONY: (c, r) => { behind("ONY")(c, r);  // Onyxia
      dragon(c, r, { col: "#2a2228", belly: "#5a4a50", wing: "#3a2a30", eye: "#ffd23f", fire: true }); },
    BARROW: (c, r) => { behind("BARROW")(c, r);  // Sonya Darkhallow
      figure(c, r, { skin: "#9a8ab8", body: "#3a2a5a", trim: "#c8b8ff", robe: true, ears: "elf", hat: "hood", hood: "#2a1a44", longHair: "#2a2a4a", glow: "#e8e0ff", weapon: "staff", weaponCol: "#e8e0ff", orb: "#c8b8ff" }); },
    HYJAL: (c, r) => { behind("HYJAL")(c, r);  // the Wild King
      figure(c, r, { top: 70, h: 430, wide: 1.3, skin: "#8a6a4a", body: "#5a4a2a", legs: "#4a3a1e", arms: "#5a4a2a", hat: "antlers", leaves: "#5bd24a", glow: "#c8ff5a", beard: "#3a8a3a", weapon: "staff", weaponCol: "#5bd24a" }); },
  };
  return { DUNGEONS, BOSSES };
};
