// An illustrated teaching model, not a fluid simulation or a measured section.
import * as K from './vendor/anatomy/iso-kit.js';

export const PHASES = {
  neutral: {name:'Neutral conditions', west:38, east:92, reach:.55, wind:1,
    title:'Winds concentrate warm water in the west.',
    windText:'Trade winds blow from South America towards Indonesia.',
    warmText:'A thicker layer of warm water builds up in the west.',
    coldText:'In the east, colder water rises from below to the surface.'},
  nino: {name:'El Niño', west:58, east:61, reach:.97, wind:.38,
    title:'With weaker winds, warm water spreads east.',
    windText:'Trade winds weaken. The arrows become shorter.',
    warmText:'Warming extends across the central and eastern Pacific.',
    coldText:'Less cold water rises in the east.'},
  nina: {name:'La Niña', west:26, east:103, reach:.36, wind:1.55,
    title:'Stronger winds increase the contrast between east and west.',
    windText:'Trade winds strengthen. The arrows become longer.',
    warmText:'Warm water becomes more concentrated in the west.',
    coldText:'More cold water rises in the east.'}
};
export const W=900, H=420;
const extents=[...K.boxCorners({x:-275,y:-92,w:550,d:199,r:12},-24,6),
  ...K.boxCorners({x:-254,y:-72,w:508,d:144,r:1},11,128),
  ...K.boxCorners({x:-231,y:-19,w:415,d:14,r:0},157,159.5)];
export const P=K.fitProjection(extents,W,H,{pad:27,azimuth:76,elevation:25});
const project = points => points.map(p=>K.iso(p,P));
const path = (points,closed=false) => K.pathOf(project(points),closed);
const polygon = (pts,fill,extra='') => `<path d="${path(pts,true)}" fill="${fill}" ${extra}/>`;
const solid = (paths,cls='ceramic')=>K.solidSvg(paths,{tone:'mid',crease:'faint',className:cls});
const box = (x,y,w,d,z,h,r=1,cls='ceramic')=>solid(K.slabOf({x,y,w,d,r},z,h,P,6,.6),cls);
const line = (pts,cls)=>`<path d="${path(pts)}" class="${cls}"/>`;
const zTop=112, yBack=-67, yFront=67, xWest=-226, xEast=226;

export function staticScene(){
  let s=`<defs><filter id="ground-blur" x="-30%" y="-100%" width="160%" height="300%"><feGaussianBlur stdDeviation="7"/></filter>
    <linearGradient id="cold-depth" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#69aab9"/><stop offset="1" stop-color="#286c83"/></linearGradient>
    <linearGradient id="warm-depth" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#df976b"/><stop offset="1" stop-color="#bf6d51"/></linearGradient>
    <linearGradient id="surface" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#e6ab7b"/><stop id="warm-stop" offset=".55" stop-color="#d98961"/><stop id="cool-stop" offset=".82" stop-color="#76b9c3"/><stop offset="1" stop-color="#60a5b6"/></linearGradient></defs>`;
  s+=`<path d="${K.haloOf({x:-274,y:-91,w:548,d:198,r:14},-25,1,P)}" fill="#536873" opacity=".20" filter="url(#ground-blur)"/>`;
  const feet=K.corners({x:-271,y:-88,w:542,d:191,r:8},22).sort((a,b)=>K.depthOf([...a,0],P)-K.depthOf([...b,0],P));
  for(const [x,y] of feet){s+=solid(K.cylinder(x,y,9,-24,4,P,32,.5),'rubber');s+=solid(K.cylinder(x,y,7,-20,10,P,32,.5),'metal');}
  s+=box(-275,-92,550,199,-10,10,12,'base');
  s+=box(-272,-89,544,193,0,5,10,'ceramic');
  s+=K.lineSvg(K.planOutline({x:-266,y:-83,w:532,d:181,r:7},5.1,P),{tone:'faint'});
  s+=box(-255,-72,510,144,5,6,3,'metal');
  // Rear edge is drawn before the water; the open front is a deliberate cut face.
  s+=box(-254,-72,508,5,11,104,1,'ceramic');
  for(const x of [-264,264])for(const y of [-79,91]){
    s+=solid(K.cylinder(x,y,2.7,5,1,P,20,.2),'metal');
    s+=K.lineSvg(K.lineOnTop([x-1,y-1],[x+1,y+1],6.1,P),{tone:'mid'});
  }
  return s;
}

function coast(side){
  const x0=side<0?-254:226;
  let s=box(x0,-67,28,134,11,101,0,'coast');
  const shape=side<0?[[0,-67],[28,-67],[25,-42],[27,-19],[20,2],[27,25],[22,48],[28,67],[0,67]]:
    [[0,-67],[28,-67],[28,67],[0,67],[5,48],[2,26],[8,4],[4,-22],[7,-46]];
  s+=solid(K.extrude(shape.map(([x,y])=>[x+x0,y]),112,4,P,{convex:false,bevel:.4}),'land');
  for(let level=0;level<3;level++){
    const spine=[];for(let i=0;i<=20;i++){const y=-57+i*5.7;const wave=Math.sin(i*.63)*2;spine.push([x0+14+wave-(3-level),y]);}
    const outline=[...spine.map(([x,y])=>[x-(5-level),y]),...spine.slice().reverse().map(([x,y])=>[x+(5-level),y])];
    s+=solid(K.extrude(outline,116+level*4,4,P,{convex:false,bevel:.25}),'land');
  }
  return s;
}

export function boundaryAt(t,state){return state.west+(state.east-state.west)*(t*t*(3-2*t));}

export function waterScene(state){
  const bottom=11;
  const ts=Array.from({length:61},(_,i)=>i/60);
  const boundary=ts.map(t=>[xWest+(xEast-xWest)*t,yFront,boundaryAt(t,state)]);
  let s='';
  s+=polygon([[xWest,yFront,bottom],[xEast,yFront,bottom],[xEast,yFront,zTop],[xWest,yFront,zTop]],'url(#cold-depth)');
  s+=polygon([[xWest,yFront,zTop],[xEast,yFront,zTop],...boundary.slice().reverse()],'url(#warm-depth)');
  // The surface and cut face share exactly the same top edge.
  s+=polygon([[xWest,yBack,zTop],[xEast,yBack,zTop],[xEast,yFront,zTop],[xWest,yFront,zTop]],'url(#surface)');
  s+=line(boundary,'thermocline');
  s+=line([[xWest,yFront,bottom],[xEast,yFront,bottom],[xEast,yFront,zTop],[xWest,yFront,zTop],[xWest,yFront,bottom]],'water-edge');
  // Upwelling is a qualitative arrow, intentionally on the cut plane.
  const x=188, y=yFront+.2, zEnd=Math.min(104,state.east-7);
  const curve=Array.from({length:31},(_,i)=>{const t=i/30;return [x-55*(1-t)**2,y,25+(zEnd-25)*t]});
  s+=`<g opacity="${.35+state.wind*.4}">${line(curve,'upwelling')}`;
  s+=polygon([[x-4,y,zEnd-5],[x,y,zEnd+3],[x+4,y,zEnd-5]],'#e4f6f7')+'</g>';
  // Thin highlight tracks on the top face suggest water, without synthetic readings.
  for(let row=0;row<4;row++){
    const y=-46+row*28;
    s+=line(Array.from({length:47},(_,i)=>{const x=-212+i*9;return [x,y+Math.sin(x*.035+row)*1.4,zTop+.1]}),'surface-track');
  }
  return s;
}

export function frontScene(){
  let s=coast(-1)+coast(1);
  s+=box(-253,68,506,3,11,3,0,'metal');
  // A small engraved maker plate; all explanatory labels remain in HTML.
  s+=box(-95,81,190,15,5,1,1,'plaque');
  s+=K.faceTextSvg(K.topMatrix([0,91],6.1,P),'PACIFIC · EQUATORIAL SECTION',{size:5.6,tone:'hi',anchor:'middle'});
  return s;
}

export function windScene(state){
  let s='';const length=48+state.wind*49;
  for(let i=0;i<3;i++){
    const x=184-i*145,y=-12,z=157;
    const ring=[[x,y-2],[x-length+12,y-2],[x-length+12,y-7],[x-length,y],[x-length+12,y+7],[x-length+12,y+2],[x,y+2]];
    s+=solid(K.extrude(ring,z,2.5,P,{convex:false,bevel:.25}),'wind');
  }
  return s;
}

export function surfaceGradient(state){
  const a=K.iso([xWest,0,zTop],P), b=K.iso([xEast,0,zTop],P);
  return {x1:a[0],y1:a[1],x2:b[0],y2:b[1],warm:Math.min(.9,state.reach*.8),cold:Math.min(.99,state.reach+.26)};
}
