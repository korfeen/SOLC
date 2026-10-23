const fs = require('fs');
const path = require('path');
const Module = require('module');
const file = path.resolve(__dirname, '../../../tools/gen-art.js');
const mod = new Module(file, module);
mod.filename = file;
mod.paths = Module._nodeModulePaths(path.dirname(file));
mod._compile(fs.readFileSync(file, 'utf8') + '\nmodule.exports._fit={alignLift,register,transform,snap,MATCH_BOTTOM,MATCH_HEAD};', file);
const a = mod.exports;
const {alignLift, register, transform, snap, MATCH_BOTTOM, MATCH_HEAD} = a._fit;
const part = process.argv[2];
const layer = part === 'head' ? 'headwear' : part === 'suit' ? 'suit' : 'outfit';
const bare = layer !== 'headwear';
const worn = a.load(path.join(__dirname, part + '-worn.png'));
let piece = a.key(a.load(path.join(__dirname, part + '-generated.png')));
const lift = alignLift(piece, worn);
if (lift && lift.after < lift.before - 2 && (Math.abs(lift.s - 1) > .004 || Math.abs(lift.tx) > 2 || Math.abs(lift.ty) > 2)) piece = transform(piece, lift);
const t = register(worn, a.ogre('painted', null, bare), piece, bare ? MATCH_BOTTOM : MATCH_HEAD);
if (t && t.score > .6) {
  piece = transform(piece, t);
  console.log('Original registration:', JSON.stringify(t));
} else piece = snap(piece, layer, a.RULES[layer]);
if (bare) piece = a.extendBottom(piece);
a.save(path.join(__dirname, 'crit_bat_original_' + part + '.png'), piece);
const pic = a.ogre('painted', null, bare);
for (let i = 0; i < pic.length; i += 4) {
  const alpha = piece[i + 3] / 255;
  for (let c = 0; c < 3; c++) pic[i + c] = Math.round(piece[i + c] * alpha + pic[i + c] * (1 - alpha));
  pic[i + 3] = Math.round(255 * alpha + pic[i + 3] * (1 - alpha));
}
a.save(path.join(__dirname, part + '-review.png'), pic, 512);
a.save(path.join(__dirname, 'ref_original_' + part + '.png'), pic, 1024);
