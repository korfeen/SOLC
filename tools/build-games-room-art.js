// Compile the approved browser room into one native WoW texture, without cropping the scene.
const fs=require('fs'),path=require('path');
const {decodePng,resample,writeBlp}=require('../tools/convert-art');
const source=process.argv[2]||path.join(__dirname,'games-room','overview.png');
const target=process.argv[3]||path.join(__dirname,'..','Media','GamesRoom','Overview.blp');
const image=decodePng(source);
fs.mkdirSync(path.dirname(target),{recursive:true});
// Power-of-two storage; the page restores the painting's wide aspect ratio.
writeBlp(target,1024,1024,resample(image,0,0,image.width,image.height,1024,1024));
console.log('Games Room overview built: '+fs.statSync(target).size+' bytes.');
