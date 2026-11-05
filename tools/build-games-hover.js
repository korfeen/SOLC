// Native UI contour masks: hand-traced visible object edges in the approved 1492x1054 room.
const fs=require('fs'),path=require('path');
const {writeBlp}=require('../tools/convert-art');
const {writePng}=require('../tools/make-role-icons');
const W=1491,H=1055,N=512;
const contours={
 puzzles:[[[187,274],[183,152],[166,111],[168,92],[190,89],[188,59],[195,40],[205,47],[210,76],[229,77],[259,65],[281,57],[304,40],[323,36],[330,20],[344,8],[356,6],[367,23],[382,29],[394,47],[424,58],[459,69],[484,76],[495,67],[498,51],[508,52],[514,68],[512,86],[534,94],[547,110],[532,125],[532,584],[521,594]],[[240,614],[518,596]]],
 paint:[[[0,274],[181,286],[263,619],[267,641],[0,694]],[[33,137],[41,137],[64,190],[55,200],[33,144]],[[25,239],[114,245],[123,270],[24,260]],[[145,267],[145,248],[151,243],[158,247],[162,269]]],
 couronne:[[[306,628],[743,541],[762,541],[1206,628],[1210,653],[1203,736],[1178,753],[1170,766],[1187,791],[1193,810],[1190,829],[1182,844],[1170,859],[1174,873],[1172,889],[1160,899],[1135,901],[1119,891],[1118,879],[1125,858],[1110,841],[1103,822],[1106,803],[1116,786],[1124,776],[1121,760],[810,897],[795,909],[786,929],[787,940],[797,953],[803,972],[803,987],[799,1002],[790,1019],[779,1040],[777,1055]],[[730,1055],[722,1038],[708,1021],[697,1006],[690,989],[692,968],[700,952],[714,939],[711,925],[707,913],[694,899],[400,770],[402,781],[414,797],[419,817],[417,837],[409,858],[402,872],[407,886],[405,899],[389,907],[357,904],[347,895],[347,879],[350,867],[343,852],[333,836],[329,817],[333,800],[340,786],[351,774],[349,757],[318,743],[308,719],[306,628]]],
 arcade:[[[906,552],[905,454],[908,439],[930,429],[946,415],[957,353],[968,289],[966,276],[958,261],[947,248],[950,221],[954,196],[961,190],[976,191],[993,187],[1011,177],[1030,165],[1047,157],[1064,155],[1081,158],[1097,167],[1118,181],[1136,187],[1158,191],[1166,191],[1168,178],[1176,176],[1185,182],[1233,214],[1234,471]],[[1234,471],[1230,622]]],
 claw:[[[1233,472],[1242,131],[1238,126],[1238,119],[1244,114],[1250,112],[1257,117],[1451,94],[1456,87],[1463,86],[1470,92],[1471,103],[1491,112]],[[1491,708],[1477,717],[1460,729],[1437,724],[1436,710],[1247,674],[1247,694],[1230,690],[1227,681],[1229,477],[1233,472]]]
};
const roomSource=fs.existsSync('output/games-room-mockup/assets/games-room.png')?'output/games-room-mockup/assets/games-room.png':path.join(__dirname,'games-room','overview.png');
const room=require('../tools/convert-art').decodePng(roomSource);
const crest=[];
for(let x=215;x<=536;x+=2){let found=null;for(let y=0;y<135;y++){const i=(y*room.width+x)*4,r=room.rgba[i],g=room.rgba[i+1],b=room.rgba[i+2];if(r>105&&g>48&&r>g*1.24&&g>b*1.4){found=y;break}}if(found!==null)crest.push([x,found]);}
const smooth=crest.map((p,i)=>[p[0],[...crest.slice(Math.max(0,i-2),i+3).map(p=>p[1])].sort((a,b)=>a-b)[Math.floor(crest.slice(Math.max(0,i-2),i+3).length/2)]]);
contours.puzzles=[[[198,277],[196,103],[186,99],[188,94],[186,56],[192,48],[198,43],[205,46],[211,54],[210,76],[214,88]],smooth,[[536,116],[532,128],[531,366],[528,529],[534,579],[525,591],[260,619]]];
const out='output/games-hover';fs.mkdirSync(out,{recursive:true});
const meta={};
// Preserve each supplied Figma outline, including intentional occluded gaps.
const userMasks={};
for(const key of ['claw','arcade','puzzles','couronne','paint']){
const clawMask=require('../tools/convert-art').decodePng(path.join(__dirname,key+'-outline-user.png'));
let clear=0,visible=0;for(let i=3;i<clawMask.rgba.length;i+=4){if(clawMask.rgba[i]===0)clear++;else visible++;}
if(!clear||!visible||Math.abs(clawMask.width/W-1)>.01||Math.abs(clawMask.height/H-1)>.01)throw Error('Invalid transparent room-size outline: '+key);
console.log(key+': '+clawMask.width+'x'+clawMask.height+', '+visible+' stroke pixels');
const clawDistance=new Float32Array(clawMask.width*clawMask.height).fill(24);
let clawBounds={x0:clawMask.width,y0:clawMask.height,x1:0,y1:0};
for(let y=0;y<clawMask.height;y++)for(let x=0;x<clawMask.width;x++){
 if(clawMask.rgba[(y*clawMask.width+x)*4+3]<128)continue;
 clawBounds.x0=Math.min(clawBounds.x0,x);clawBounds.y0=Math.min(clawBounds.y0,y);
 clawBounds.x1=Math.max(clawBounds.x1,x+1);clawBounds.y1=Math.max(clawBounds.y1,y+1);
 for(let yy=Math.max(0,y-24);yy<Math.min(clawMask.height,y+25);yy++)for(let xx=Math.max(0,x-24);xx<Math.min(clawMask.width,x+25);xx++){
  const i=yy*clawMask.width+xx;clawDistance[i]=Math.min(clawDistance[i],Math.hypot(xx-x,yy-y));
 }
}
userMasks[key]={mask:clawMask,distance:clawDistance,bounds:clawBounds};
}
function distance(x,y,a,b){const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy||1)));return Math.hypot(x-a[0]-t*dx,y-a[1]-t*dy)}
for(const [key,lines]of Object.entries(contours)){
 const user=userMasks[key],clawMask=user?.mask,clawBounds=user?.bounds;
 const points=user?[[clawBounds.x0*W/clawMask.width,clawBounds.y0*H/clawMask.height],[clawBounds.x1*W/clawMask.width,clawBounds.y1*H/clawMask.height]]:lines.flat(),x0=Math.max(0,Math.min(...points.map(p=>p[0]))-24),y0=Math.max(0,Math.min(...points.map(p=>p[1]))-24),x1=Math.min(W,Math.max(...points.map(p=>p[0]))+24),y1=Math.min(H,Math.max(...points.map(p=>p[1]))+24);
 const segments=lines.flatMap(line=>line.slice(1).map((p,i)=>[line[i],p]));const rgba=Buffer.alloc(N*N*4);
 for(let y=0;y<N;y++)for(let x=0;x<N;x++){
  const sx=x0+(x+.5)/N*(x1-x0),sy=y0+(y+.5)/N*(y1-y0);
  let d=24;for(const[a,b]of segments){if(sx<Math.min(a[0],b[0])-24||sx>Math.max(a[0],b[0])+24||sy<Math.min(a[1],b[1])-24||sy>Math.max(a[1],b[1])+24)continue;d=Math.min(d,distance(sx,sy,a,b))}
  if(user)d=user.distance[Math.min(clawMask.height-1,Math.floor(sy/H*clawMask.height))*clawMask.width+Math.min(clawMask.width-1,Math.floor(sx/W*clawMask.width))];
  const p=(y*N+x)*4;rgba[p]=255;rgba[p+1]=204;rgba[p+2]=107;
  rgba[p+3]=Math.round(255*Math.min(1,.35*Math.exp(-d*d/10)+.26*Math.exp(-d*d/90)));
 }
 writeBlp(path.join(out,'Hover_'+key+'.blp'),N,N,rgba);
 writePng(path.join(out,'Hover_'+key+'.png'),N,N,rgba);
 meta[key]={file:'Hover_'+key,x:x0/W,y:y0/H,w:(x1-x0)/W,h:(y1-y0)/H};
}
let lua='-- Generated contour-mask placement; rebuild with tools/build-games-hover.js.\nlocal _, ns = ...\nns.GamesRoomGlows = {\n';
for(const [key,m]of Object.entries(meta))lua+=`    ${key} = { file="${m.file}", x=${m.x.toFixed(8)}, y=${m.y.toFixed(8)}, w=${m.w.toFixed(8)}, h=${m.h.toFixed(8)} },\n`;
fs.writeFileSync(path.join(out,'GamesRoomGlows.lua'),lua+'}\n');
fs.writeFileSync(path.join(out,'contours.json'),JSON.stringify({width:W,height:H,contours,meta},null,2));
console.log('Built five cropped gold contour masks.');
