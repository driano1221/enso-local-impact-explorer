// Qualitative illustrated section, using the existing ENSO phase states unchanged.
export {PHASES} from './aprovado/pacifico-model.js';
export const W=560,H=300;
const X=57,DX=474,TOP=183,DEPTH=137;
const point=(t,z)=>[X+DX*(1-Math.pow(1-t,1.45)),TOP-22*t+(112-z)*DEPTH/112];
const fmt=p=>p.map(n=>n.toFixed(2)).join(',');
const curve=(fn)=>Array.from({length:65},(_,i)=>fmt(point(i/64,fn(i/64)))).join(' L');
export const boundaryAt=(t,state)=>state.west+(state.east-state.west)*t*t*(3-2*t);
const cloud=(x,y)=>`<g transform="translate(${x} ${y})">
 <path d="M-59 12C-75-2-65-23-48-22C-51-48-18-62-3-38C17-57 45-37 40-18C67-18 72 13 50 24L-42 27Z" fill="url(#cloud-shade)"/>
 <path d="M-57-15C-50-31-31-34-20-21C-20-39 1-46 13-31C24-34 37-22 36-10" fill="#f7fbfd"/>
 <path d="M-65 6C-54-11-36-12-25 0C-13-14 4-10 10 3C27-7 44 1 46 15C31 27-46 31-65 6Z" fill="#cad9e2"/>
 <path d="M-57 8C-47-3-32-4-23 6M-8 5C1-2 13 1 18 8" fill="none" stroke="#f6fafc" stroke-width="6" stroke-linecap="round"/>
 <path d="M-31 37l-8 15M-9 36l-8 15M13 35 5 50" fill="none" stroke="#68add1" stroke-width="3" stroke-linecap="round" opacity=".7"/></g>`;

export function staticScene(){return `<defs>
 <linearGradient id="cold-depth" x2="0" y2="1"><stop stop-color="#58c9ed"/><stop offset=".45" stop-color="#168ecb"/><stop offset="1" stop-color="#195e9d"/></linearGradient>
 <radialGradient id="warm-depth" cx=".08" cy=".15" r=".95"><stop stop-color="#e64032"/><stop offset=".35" stop-color="#f3482e"/><stop offset=".68" stop-color="#ff9c4a"/><stop offset="1" stop-color="#fff0c7"/></radialGradient>
 <linearGradient id="surface" gradientUnits="userSpaceOnUse"><stop stop-color="#e84132"/><stop id="warm-stop" offset=".55" stop-color="#ff8b46"/><stop id="cool-stop" offset=".82" stop-color="#62cce7"/><stop offset="1" stop-color="#249ccf"/></linearGradient>
 <linearGradient id="cloud-shade" x2=".3" y2="1"><stop stop-color="#f7fbfd"/><stop offset=".5" stop-color="#d9e5ec"/><stop offset="1" stop-color="#9eb6c6"/></linearGradient>
 <linearGradient id="ocean-side" x2="1" y2="1"><stop stop-color="#51bee0"/><stop offset="1" stop-color="#247da9"/></linearGradient>
 <filter id="soft-shadow" x="-.2" y="-.5" width="1.4" height="2"><feGaussianBlur stdDeviation="5"/></filter>
 </defs><ellipse cx="309" cy="326" rx="244" ry="8" fill="#376c8c" opacity=".1" filter="url(#soft-shadow)"/>
 <path d="M531 161 565 139 565 291 531 298Z" fill="url(#ocean-side)" stroke="#2a85ad" stroke-width="1"/>`;}

export function waterScene(state){
 const boundary=curve(t=>boundaryAt(t,state));
 const topLeft=fmt(point(0,112)),topRight=fmt(point(1,112));
 let s=`<path d="M${topLeft} L${topRight} L${fmt(point(1,0))} L${fmt(point(0,0))}Z" fill="url(#cold-depth)"/>`;
 s+=`<path d="M${topLeft} L${topRight} L${Array.from({length:65},(_,i)=>fmt(point(1-i/64,boundaryAt(1-i/64,state)))).join(' L')}Z" fill="url(#warm-depth)"/>`;
 const warmPath=`M${topLeft} L${topRight} L${Array.from({length:65},(_,i)=>fmt(point(1-i/64,boundaryAt(1-i/64,state)))).join(' L')}Z`;
 s+=`<defs><clipPath id="warm-layer-clip"><path d="${warmPath}"/></clipPath></defs><g clip-path="url(#warm-layer-clip)">`;
 for(let i=0;i<5;i++){
   const y=193+i*11,tip=126+i*38;
   s+=`<path d="M35 ${y}C96 ${y-17} ${tip+59} ${y-12} ${tip} ${y+7}C${tip-24} ${y+16} 74 ${y+18} 35 ${y+18}" fill="none" stroke="#ffe5b8" stroke-width="${i===0?2.5:1.4}" opacity="${.72-i*.065}"/>`;
 }
 s+='</g>';
 // Flow-like contours illustrate layer geometry; they do not encode measured currents.
 for(let i=1;i<3;i++){
   const f=i/3;
   s+=`<path d="M${curve(t=>boundaryAt(t,state)+(112-boundaryAt(t,state))*f)}" fill="none" stroke="${i<3?'#fff2d1':'#ffc078'}" stroke-width="1.5" opacity=".4"/>`;
 }
 for(let i=1;i<7;i++){
   s+=`<path d="M${curve(t=>boundaryAt(t,state)*(i/7+.24*Math.sin(Math.PI*t*1.5)*(i/7)*(1-i/7)))}" fill="none" stroke="#c7f0f9" stroke-width="1.4" opacity=".6"/>`;
 }
 s+=`<path d="M57 183 91 159 565 139 531 161Z" fill="url(#surface)" stroke="#e5f7f9" stroke-width="1.2"/>`;
 for(let i=0;i<4;i++)s+=`<path d="M${79+i*9} ${176-i*5}Q278 ${160-i*5} ${548+i*4} ${151-i*3}" fill="none" stroke="#fff6da" stroke-width="1" opacity=".36"/>`;
 s+=`<path d="M${boundary}" fill="none" stroke="#fff0c9" stroke-width="4.5" opacity=".8"/>`;
 const end=point(.94,Math.min(104,state.east-6));
 s+=`<g opacity="${Math.min(.95,.25+state.wind*.4)}"><path d="M${fmt(point(.72,12))}Q${fmt(point(.94,10))} ${fmt(end)}" fill="none" stroke="#d0effc" stroke-width="2.5" stroke-linecap="round"/><path d="m${end[0]-5},${end[1]+8} 5,-9 5,9" fill="none" stroke="#d0effc" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></g>`;
 return s;
}
export function frontScene(){return `<path d="M57 183 531 161 531 298 57 320Z" fill="none" stroke="#35799d" stroke-width="1" opacity=".55"/>
 <path d="m57 183-15-8 13-11 36-5Z" fill="#94b892"/><path d="m531 161 16-15 18-7-5 18Z" fill="#b2c8a7"/>
 <path d="m44 176 12-22 11 12 9-17 15 10-19 16Z" fill="#bdcfa9"/><path d="m546 150 8-20 11 9Z" fill="#abc4ad"/>`;}
export function windScene(state){
 let s=cloud(112+(state.reach-.36)*125,108);
 const length=17+state.wind*17;
 for(const x of [270,339,408,477,546])s+=`<path d="M${x} 67h-${length}m7-4-7 4 7 4" fill="none" stroke="#155a83" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>`;
 return s;
}
export function surfaceGradient(state){return {x1:57,y1:173,x2:550,y2:151,warm:Math.min(.9,state.reach*.8),cold:Math.min(.99,state.reach+.26)};}
