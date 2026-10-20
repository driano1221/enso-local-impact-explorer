import {geoProjection,geoPath,geoGraticule,geoArea} from './vendor/d3-geo/d3-geo.bundle.js';
// Qualitative illustration: stylised contours, never measured SST or physical eddies.
const host=document.getElementById('atlas-stage'),reduced=matchMedia('(prefers-reduced-motion: reduce)');
const english=document.documentElement.lang==='en',canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');
canvas.tabIndex=0;canvas.setAttribute('role','img');
canvas.setAttribute('aria-label',english?'Illustrated ENSO map. Drag or use left and right arrows to change the view. Colours are qualitative, not measured temperatures.':'Mapa ilustrativo do ENSO. Arraste ou use as setas esquerda e direita para mudar a vista. Cores qualitativas, não temperaturas medidas.');
let countries,width=0,height=0,longitude=210,zoom=1,phase='neutral',strength=0,frame=0,drag=null;
const targets={neutral:0,nino:1,nina:-1},wrap=x=>((x+180)%360+360)%360-180;
// Standard Mollweide oval; D3 handles spherical clipping and geographic rotation.
export function mollweide(lambda,phi){
 let theta=phi;
 if(Math.abs(phi)>=Math.PI/2-1e-8)theta=Math.sign(phi)*Math.PI/2;
 else for(let i=0;i<12;i++){const d=(2*theta+Math.sin(2*theta)-Math.PI*Math.sin(phi))/(2+2*Math.cos(2*theta));theta-=d;if(Math.abs(d)<1e-9)break;}
 return [2*Math.SQRT2/Math.PI*lambda*Math.cos(theta),Math.SQRT2*Math.sin(theta)];
}
mollweide.invert=(x,y)=>{const theta=Math.asin(Math.max(-1,Math.min(1,y/Math.SQRT2)));return [Math.PI*x/(2*Math.SQRT2*Math.cos(theta)),Math.asin(Math.max(-1,Math.min(1,(2*theta+Math.sin(2*theta))/Math.PI)))];};
const projection=geoProjection(mollweide).precision(.4),sphere={type:'Sphere'},graticule=geoGraticule().step([30,30])();
// Three small illustration textures are composed once, then reprojected only on camera changes.
// A continuous, qualitative ocean surface. Colours are not SST estimates.
const palette=[[28,76,122],[37,107,158],[49,143,180],[90,179,196],[147,209,208],[203,228,207],[239,235,182],[250,209,135],[247,166,99],[233,117,72],[211,73,48],[172,47,39]];
const TW=720,TH=360;
export function illustration(lon,lat,state){
 // A broad equator-to-pole teaching gradient; only the Pacific changes with ENSO.
 const radians=Math.PI/180,t=(lon-120)/172;
 const latitude=Math.abs(lat+2*Math.sin(lon*radians*2)*Math.cos(lat*radians));
 const base=.64-1.58*Math.pow(latitude/90,.8);
 const basin=lon>120&&lon<292?Math.pow(Math.sin(Math.PI*t),.45):0;
 const tropical=Math.exp(-Math.pow(lat/26,4));
 const west=1/(1+Math.exp((lon-(190+state*40))/16));
 const tongueAxis=-2+1.3*Math.sin((lon-180)*radians*3);
 const tongueWidth=5+5/(1+Math.exp(-(lon-220)/15));
 const tongue=Math.exp(-Math.pow((lat-tongueAxis)/tongueWidth,2));
 const cold=(.86-.50*state)*(1-west)*tongue;
 const warm=.30*west*Math.exp(-Math.pow(lat/18,2));
 // Broad bends in the painted boundaries, without random weather-like speckle.
 const bend=.045*Math.sin(lon*radians*5+lat*radians*8)*Math.cos(lat*radians);
 return Math.max(-1,Math.min(1,base+bend+basin*tropical*(warm-cold)));
}
function makeTexture(state){
 const data=new Uint8ClampedArray(TW*TH*4);
 for(let y=0;y<TH;y++)for(let x=0;x<TW;x++){
  const value=illustration(x/2,90-y/2,state),level=(value+1)*5.5,lo=Math.floor(level),hi=Math.min(11,lo+1),mix=level-lo;
  const offset=(y*TW+x)*4;
  for(let c=0;c<3;c++)data[offset+c]=palette[lo][c]*(1-mix)+palette[hi][c]*mix;
  data[offset+3]=255;
 }
 return data;
}
const textures=[-1,0,1].map(makeTexture),thermalLayers=[-1,0,1].map(()=>document.createElement('canvas'));
const landLayer=document.createElement('canvas'),landContext=landLayer.getContext('2d');
let landTexture=null,geometryKey='',moving=false;
function prepareGeometry(){
 const key=[width,height,longitude,moving,!!landTexture].join(',');if(key===geometryKey)return;
 geometryKey=key;
 // A bounded raster during movement; geography and labels remain full-resolution vectors.
 const scale=Math.min(1,(moving?280:520)/width),w=Math.ceil(width*scale),h=Math.ceil(height*scale);
 const projected=thermalLayers.map(c=>{c.width=w;c.height=h;return c.getContext('2d').createImageData(w,h);});
 const relief=document.createElement('canvas');relief.width=w;relief.height=h;
 const reliefContext=relief.getContext('2d'),land=reliefContext.createImageData(w,h);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){
  const px=((x+.5)/scale-width/2)/projection.scale(),py=(height/2-(y+.5)/scale)/projection.scale();
  if(px*px/8+py*py/2>1)continue;
  const ll=mollweide.invert(px,py),lat=ll[1]*180/Math.PI,earthLon=wrap(ll[0]*180/Math.PI+longitude),lon=(earthLon+360)%360,o=(y*w+x)*4;
  const tx=Math.min(TW-1,Math.floor(lon/360*TW)),ty=Math.min(TH-1,Math.floor((90-lat)/180*TH)),ti=(ty*TW+tx)*4;
  for(let n=0;n<3;n++)for(let c=0;c<4;c++)projected[n].data[o+c]=textures[n][ti+c];
  if(landTexture){
   const sx=Math.min(1023,Math.floor((earthLon+180)/360*1024)),sy=Math.min(511,Math.floor((90-lat)/180*512)),i=(sy*1024+sx)*4;
   for(let c=0;c<4;c++)land.data[o+c]=landTexture[i+c];
  }
 }
 thermalLayers.forEach((c,n)=>c.getContext('2d').putImageData(projected[n],0,0));
 const ratio=Math.min(devicePixelRatio,2);landLayer.width=width*ratio;landLayer.height=height*ratio;landContext.setTransform(ratio,0,0,ratio,0,0);
 const path=geoPath(projection,landContext),g=landContext;
 g.beginPath();path(graticule);g.strokeStyle='#effaff22';g.lineWidth=.5;g.stroke();
 if(moving&&landTexture){reliefContext.putImageData(land,0,0);g.drawImage(relief,0,0,width,height);}
 else {
 const landPath=new Path2D(geoPath(projection)(countries));g.fillStyle='#dce3df';g.fill(landPath);
 if(landTexture){reliefContext.putImageData(land,0,0);g.save();g.clip(landPath);g.drawImage(relief,0,0,width,height);g.restore();}
 // Country borders and land relief are cached together for all phase transitions.
 g.strokeStyle='#f6faf2';g.lineWidth=1.2;g.stroke(landPath);g.strokeStyle='#93a9ac';g.lineWidth=.4;g.stroke(landPath);
 }
 g.beginPath();path({type:'LineString',coordinates:Array.from({length:36},(_,i)=>[wrap(144+i*3.8),0])});g.strokeStyle='#ffffffb0';g.lineWidth=.8;g.setLineDash([2,3]);g.stroke();g.setLineDash([]);
 const label=projection([wrap(211),32]);if(label){g.font="600 8px 'Source Sans 3',sans-serif";g.textAlign='center';g.fillStyle='#284e64';g.fillText(english?'PACIFIC OCEAN':'OCEANO PACÍFICO',label[0],label[1]);}
}
function draw(){
 if(!width||!countries||document.hidden)return;
 ctx.clearRect(0,0,width,height);projection.rotate([-longitude,0]).fitExtent([[4,5],[width-4,height-5]],sphere);
 prepareGeometry();projection.scale(projection.scale()*zoom);const path=geoPath(projection,ctx);ctx.beginPath();path(sphere);
 const sea=ctx.createLinearGradient(0,0,0,height);sea.addColorStop(0,'#e9f5f5');sea.addColorStop(.55,'#c1e4f0');sea.addColorStop(1,'#e9f3f5');ctx.fillStyle=sea;ctx.fill();ctx.save();ctx.clip();
 const level=strength+1,lo=Math.floor(level),hi=Math.min(2,lo+1),mix=level-lo;
 const left=width*(1-zoom)/2,top=height*(1-zoom)/2;
 ctx.globalAlpha=1;ctx.drawImage(thermalLayers[lo],left,top,width*zoom,height*zoom);
 if(mix){ctx.globalAlpha=mix;ctx.drawImage(thermalLayers[hi],left,top,width*zoom,height*zoom);}ctx.globalAlpha=1;
 ctx.drawImage(landLayer,left,top,width*zoom,height*zoom);
 ctx.strokeStyle='#164c70';ctx.fillStyle='#164c70';ctx.lineWidth=1.3;
 for(const lon of [180,215,250]){const start=projection([wrap(lon),6]),end=projection([wrap(lon-11+strength*5),6]);if(!start||!end||Math.abs(start[0]-end[0])>width/4)continue;ctx.beginPath();ctx.moveTo(...start);ctx.lineTo(...end);ctx.stroke();ctx.beginPath();ctx.moveTo(...end);ctx.lineTo(end[0]+4,end[1]-2.3);ctx.lineTo(end[0]+4,end[1]+2.3);ctx.closePath();ctx.fill();}
 ctx.restore();ctx.beginPath();path(sphere);ctx.strokeStyle='#457790';ctx.lineWidth=.9;ctx.stroke();
}
function resize(){width=host.clientWidth;height=host.clientHeight;const ratio=Math.min(devicePixelRatio,2);canvas.width=width*ratio;canvas.height=height*ratio;canvas.style.width=width+'px';canvas.style.height=height+'px';ctx.setTransform(ratio,0,0,ratio,0,0);draw();}
function animate(target){
 cancelAnimationFrame(frame);moving=target.longitude!==longitude;if(reduced.matches||document.hidden){({longitude,zoom,strength}=target);moving=false;draw();return;}
 const from={longitude,zoom,strength},start=performance.now();
 function tick(now){const t=Math.min(1,(now-start)/800),q=t*t*(3-2*t);longitude=from.longitude+(target.longitude-from.longitude)*q;zoom=from.zoom+(target.zoom-from.zoom)*q;strength=from.strength+(target.strength-from.strength)*q;if(t===1)moving=false;draw();if(t<1)frame=requestAnimationFrame(tick);}
 frame=requestAnimationFrame(tick);
}
function focus(view){animate({longitude:210,zoom:view==='pacific'?1.6:1,strength:targets[phase]});document.querySelectorAll('[data-atlas]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.atlas===view)));}
canvas.addEventListener('pointerdown',e=>{if(e.button!==0)return;cancelAnimationFrame(frame);strength=targets[phase];moving=true;drag={id:e.pointerId,x:e.clientX};canvas.setPointerCapture(e.pointerId);});
canvas.addEventListener('pointermove',e=>{if(!drag)return;longitude=wrap(longitude-((e.clientX-drag.x)/width)*200);drag.x=e.clientX;cancelAnimationFrame(frame);frame=requestAnimationFrame(draw);});
canvas.addEventListener('pointerup',e=>{if(drag?.id===e.pointerId){drag=null;moving=false;canvas.releasePointerCapture(e.pointerId);draw();}});canvas.addEventListener('pointercancel',()=>{drag=null;moving=false;draw();});
canvas.addEventListener('keydown',e=>{if(['ArrowLeft','ArrowRight','Home'].includes(e.key)){e.preventDefault();animate({longitude:e.key==='Home'?210:longitude+(e.key==='ArrowLeft'?-12:12),zoom,strength:targets[phase]});}});
// Both renderers listen to the same phase buttons; no independent scientific state.
document.querySelectorAll('[data-phase]').forEach(b=>b.addEventListener('click',()=>{phase=b.dataset.phase;animate({longitude,zoom,strength:targets[phase]});}));
document.querySelectorAll('[data-atlas]').forEach(b=>b.addEventListener('click',()=>focus(b.dataset.atlas)));
function settle(){cancelAnimationFrame(frame);moving=false;strength=targets[phase];draw();}
reduced.addEventListener('change',()=>{if(reduced.matches)settle();});document.addEventListener('visibilitychange',()=>{if(document.hidden)settle();else draw();});
try{const response=await fetch('../vendor/earth/countries.json');if(!response.ok)throw new Error('Cartography unavailable');countries=await response.json();for(const f of countries.features)if(geoArea(f)>2*Math.PI){const polys=f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates;for(const p of polys)for(const ring of p)ring.reverse();}host.replaceChildren(canvas);new ResizeObserver(resize).observe(host);resize();}
catch(error){host.textContent=english?'Map unavailable. The ocean section remains accessible.':'Mapa indisponível. O corte oceânico continua acessível.';console.warn(error);}

// Quiet vector land integrates with the ocean surface; no extra Earth image request.
if(countries){
 const c=document.createElement('canvas');c.width=1024;c.height=512;const g=c.getContext('2d');
 const worldProjection=geoProjection((lambda,phi)=>[lambda,phi]).scale(1024/(2*Math.PI)).translate([512,256]);
 const outline=new Path2D(geoPath(worldProjection)(countries));
 g.fillStyle='#dce3df';g.fill(outline);g.strokeStyle='#93a9ac';g.lineWidth=.5;g.stroke(outline);
 landTexture=g.getImageData(0,0,1024,512).data;geometryKey='';draw();
}
