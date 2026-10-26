// The claw machine's sounds (ClawMachine.lua), synthesized here and encoded to Ogg Vorbis with ffmpeg:
//   bonk  - a fist on the cabinet: a low thump, the glass rattling, a short metal ring
//   tilt  - the arcade buzzer: three harsh square-wave blasts and a falling bell
//   whir  - the carriage motor, a loop: a low hum with a little wobble and gear ticks (played back to back while it moves)
//   winch - the cable motor, a loop: like the whir but higher and thinner
//   clack - the claw's prongs snapping shut
// Run: node tools/make-claw-sounds.js   (needs ffmpeg on the PATH) -> Media/Claw/*.ogg
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const RATE = 44100;
const OUT = path.join(__dirname, "..", "Media", "Claw");

function wav(samples) {  // mono 16-bit PCM
  const buf = Buffer.alloc(44 + samples.length * 2);
  buf.write("RIFF", 0); buf.writeUInt32LE(36 + samples.length * 2, 4); buf.write("WAVE", 8);
  buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(RATE, 24); buf.writeUInt32LE(RATE * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write("data", 36); buf.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32000), 44 + i * 2);
  return buf;
}
function make(seconds, fn) {
  const n = Math.round(seconds * RATE), out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = fn(i / RATE, i);
  return out;
}
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;
// a one-pole low-pass over white noise, so it rumbles instead of hissing
function noise(cut) { let y = 0; const a = Math.exp(-2 * Math.PI * cut / RATE); return () => (y = a * y + (1 - a) * rnd()); }
function normalize(s, peak) { let m = 0; for (const v of s) m = Math.max(m, Math.abs(v)); for (let i = 0; i < s.length; i++) s[i] *= peak / m; return s; }

const sounds = {
  bonk() {
    const rumble = noise(400), rattle = noise(3000);
    let ph = 0;
    return normalize(make(0.7, (t) => {
      ph += 2 * Math.PI * (55 + 70 * Math.exp(-t * 25)) / RATE;  // (the thump drops in pitch)
      const thump = Math.sin(ph) * Math.exp(-t * 9);
      const body = rumble() * 2.5 * Math.exp(-t * 14);
      const glass = rattle() * Math.exp(-t * 7) * (0.6 + 0.4 * Math.sin(2 * Math.PI * 38 * t)) * 0.5;
      const ring = (Math.sin(2 * Math.PI * 912 * t) + 0.5 * Math.sin(2 * Math.PI * 1377 * t)) * Math.exp(-t * 11) * 0.12;
      return thump + body + glass + ring;
    }), 0.95);
  },
  tilt() {
    return normalize(make(1.6, (t) => {
      const blast = t < 1.05 ? (Math.floor(t / 0.35) % 1 === 0 && (t % 0.35) < 0.26 ? 1 : 0) : 0;
      const f = 150 + 12 * Math.sin(2 * Math.PI * 7 * t);
      const sq = Math.sign(Math.sin(2 * Math.PI * f * t)) * 0.6 + Math.sign(Math.sin(2 * Math.PI * f * 1.51 * t)) * 0.3;
      const edge = Math.min(1, (t % 0.35) / 0.01) * Math.min(1, (0.26 - (t % 0.35)) / 0.02);
      const bellT = t - 1.05;
      const bell = bellT > 0 ? Math.sin(2 * Math.PI * (660 - 200 * bellT) * bellT) * Math.exp(-bellT * 5) * 0.5 : 0;
      return sq * blast * Math.max(0, edge) * 0.8 + bell;
    }), 0.9);
  },
  whir() { return loop(0.96, 92, 0.18, 30); },
  winch() { return loop(0.72, 165, 0.12, 44); },
  clack() {
    const click = noise(6000);
    return normalize(make(0.18, (t) => {
      const a = click() * Math.exp(-t * 90);
      const b = t > 0.035 ? click() * Math.exp(-(t - 0.035) * 120) * 0.7 : 0;
      const tone = Math.sin(2 * Math.PI * 1800 * t) * Math.exp(-t * 60) * 0.3;
      return a + b + tone;
    }), 0.8);
  },
};
// A motor loop: a hum (saw-ish: a few harmonics) with a slow wobble and gear ticks; every frequency a whole number of
// cycles over the loop, so it repeats without a click; 40 ms fades so back-to-back copies blend.
function loop(seconds, hz, wobble, ticks) {
  const f = Math.round(hz * seconds) / seconds, w = Math.round(3 * seconds) / seconds, k = Math.round(ticks * seconds) / seconds;
  const hiss = noise(1800);
  const fade = 0.04;
  return normalize(make(seconds, (t) => {
    const hum = Math.sin(2 * Math.PI * f * t) + 0.5 * Math.sin(4 * Math.PI * f * t) + 0.25 * Math.sin(6 * Math.PI * f * t);
    const wob = 1 + wobble * Math.sin(2 * Math.PI * w * t);
    const tick = Math.pow(Math.max(0, Math.sin(2 * Math.PI * k * t)), 24);
    const env = Math.min(1, t / fade, (seconds - t) / fade);
    return (hum * 0.5 * wob + tick * 0.6 + hiss() * 0.25) * env;
  }), 0.55);
}

fs.mkdirSync(OUT, { recursive: true });
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "claw-sounds-"));
for (const [name, build] of Object.entries(sounds)) {
  const w = path.join(tmp, name + ".wav"), o = path.join(OUT, name + ".ogg");
  fs.writeFileSync(w, wav(build()));
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", w, "-c:a", "libvorbis", "-q:a", "5", o]);
  console.log(name, fs.statSync(o).size, "bytes");
}
fs.rmSync(tmp, { recursive: true, force: true });
