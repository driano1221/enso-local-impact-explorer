import * as T from './aprovado/vendor/three/three.module.min.js';
import {globePoint} from './aprovado/terra-geometry.js';
import {globeAngles} from './globo-orientacao.js';
import {visiblePoint,nearbyPoints,zoomDistance} from './globo-interacao.js';

export async function createLocator(host,onSelect){
  const texture=await new T.TextureLoader().loadAsync(new URL('vendor/earth/earth-day.jpg',import.meta.url).href);
  texture.colorSpace=T.SRGBColorSpace;
  const renderer=new T.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});
  const pixelRatio=Math.min(devicePixelRatio,1.5);
  renderer.setPixelRatio(pixelRatio);renderer.outputColorSpace=T.SRGBColorSpace;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(35,1,.1,20),world=new T.Group();
  scene.add(world);camera.position.z=3.4;
  texture.anisotropy=Math.min(4,renderer.capabilities.getMaxAnisotropy());
  scene.add(new T.HemisphereLight(0xe4f5ff,0x233a48,2));
  const key=new T.DirectionalLight(0xfff8e8,2.6);key.position.set(-3,4,5);scene.add(key);
  world.add(new T.Mesh(new T.SphereGeometry(1,80,56),new T.MeshPhongMaterial({map:texture,shininess:7,specular:0x152a39})));
  // Natural Earth geographic outlines, independent of the climate grids.
  const boundaries=await fetch(new URL('vendor/earth/countries.json',import.meta.url)).then(r=>{if(!r.ok)throw new Error('Country geometry unavailable');return r.json();});
  const segments=[];
  for(const f of boundaries.features){const polygons=f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates;
    for(const polygon of polygons)for(const ring of polygon)for(let i=1;i<ring.length;i++){
      const a=ring[i-1],b=ring[i];if(Math.abs(a[0]-b[0])>180)continue;
      segments.push(...globePoint(a[0],a[1],1.003),...globePoint(b[0],b[1],1.003));
    }
  }
  const outlineGeometry=new T.BufferGeometry();outlineGeometry.setAttribute('position',new T.Float32BufferAttribute(segments,3));
  world.add(new T.LineSegments(outlineGeometry,new T.LineBasicMaterial({color:0xf0f5dc,transparent:true,opacity:.42,depthWrite:false})));
  world.add(new T.Mesh(new T.SphereGeometry(1.009,64,48),new T.MeshBasicMaterial({color:0x91c7de,side:T.BackSide,transparent:true,opacity:.36,depthWrite:false})));
  const canvas=renderer.domElement;canvas.className='globo-canvas';canvas.tabIndex=0;
  canvas.setAttribute('role','group');canvas.setAttribute('aria-label','Globo interativo. Arraste ou use as setas para girar, mais e menos para ampliar. Os seletores acima também escolhem a localidade.');host.append(canvas);
  const overlay=document.createElement('canvas');overlay.className='globo-pontos';overlay.setAttribute('aria-hidden','true');host.append(overlay);
  const ctx=overlay.getContext('2d'),tip=document.createElement('div');tip.className='globo-tooltip';tip.hidden=true;host.append(tip);
  const status=document.createElement('div');status.className='globo-status';status.textContent='Pontos do catálogo';host.append(status);
  const choices=document.createElement('div');choices.className='globo-escolhas';choices.hidden=true;choices.setAttribute('aria-label','Localidades próximas');host.append(choices);
  const controls=document.createElement('div');controls.className='globo-tools';host.append(controls);
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  let raf=0,transition=null,catalogue=[],projected=[],selected=null,width=0,height=0,inView=true,drag=null;
  function schedule(){if(!raf&&!host.hidden&&inView&&!document.hidden)raf=requestAnimationFrame(frame);}
  function frame(now){
    raf=0;if(host.hidden||!inView||document.hidden)return;
    if(transition){const t=Math.min(1,(now-transition.start)/850),e=t*t*(3-2*t);world.quaternion.slerpQuaternions(transition.from,transition.to,e);if(t===1)transition=null;}
    camera.updateMatrixWorld();world.updateMatrixWorld();renderer.render(scene,camera);
    ctx.clearRect(0,0,width,height);projected=[];
    for(const p of catalogue){
      const v=p.vector.clone().applyQuaternion(world.quaternion);
      if(!visiblePoint(v,camera.position.z))continue;
      const screen=v.project(camera),x=(screen.x+1)*width/2,y=(1-screen.y)*height/2;
      if(x<0||x>width||y<0||y>height-38)continue;
      projected.push({id:p.id,nome:p.nome,iso2:p.iso2,x,y});
      if(p.id===selected?.id)continue;
      ctx.beginPath();ctx.arc(x,y,2.15,0,Math.PI*2);ctx.fillStyle='#ecf6f8';ctx.fill();ctx.strokeStyle='#264e61';ctx.lineWidth=.7;ctx.stroke();
    }
    const active=projected.find(p=>p.id===selected?.id);
    if(active){ctx.beginPath();ctx.arc(active.x,active.y,8,0,Math.PI*2);ctx.fillStyle=selected.metrica==='temperatura_c'?'#e44e36':'#207b94';ctx.fill();ctx.strokeStyle='#fff';ctx.lineWidth=2.5;ctx.stroke();ctx.beginPath();ctx.arc(active.x,active.y,12,0,Math.PI*2);ctx.strokeStyle='#ffffffaa';ctx.lineWidth=1;ctx.stroke();}
    if(active){
      ctx.font='600 12px "Source Sans 3", sans-serif';let label=active.nome;
      while(ctx.measureText(label).width>140&&label.length>1)label=label.slice(0,-2)+'…';
      const w=ctx.measureText(label).width+15,x=Math.min(width-w-5,Math.max(5,active.x+14)),y=Math.max(4,active.y-25);
      ctx.fillStyle='#11374ae8';ctx.fillRect(x,y,w,24);ctx.strokeStyle='#88acbd';ctx.lineWidth=.8;ctx.strokeRect(x,y,w,24);
      ctx.fillStyle='#fff';ctx.fillText(label,x+7,y+16);
    }
    host.dataset.state=transition?'moving':'ready';
    if(transition)schedule();
  }
  function resize(){
    if(!host.clientWidth||!host.clientHeight)return;
    width=host.clientWidth;height=host.clientHeight;
    renderer.setSize(width,height,false);overlay.width=Math.round(width*pixelRatio);overlay.height=Math.round(height*pixelRatio);ctx.setTransform(pixelRatio,0,0,pixelRatio,0,0);
    camera.aspect=width/height;camera.fov=2*Math.atan(Math.tan(35*Math.PI/360)/Math.min(1,camera.aspect))*180/Math.PI;camera.updateProjectionMatrix();schedule();
  }
  function clearInteraction(){transition=null;tip.hidden=true;choices.hidden=true;}
  function rotate(dx,dy){clearInteraction();world.quaternion.premultiply(new T.Quaternion().setFromEuler(new T.Euler(dy*.006,dx*.006,0,'XYZ')));schedule();}
  function zoom(delta){clearInteraction();camera.position.z=zoomDistance(camera.position.z,delta);schedule();}
  function focus(){
    if(!selected)return;tip.hidden=true;choices.hidden=true;
    const target=new T.Quaternion().setFromEuler(new T.Euler(...globeAngles(selected.longitude,selected.latitude),'XYZ'));
    camera.position.z=3.4;
    if(reduced.matches||document.hidden||new URLSearchParams(location.search).get('motion')==='static'){world.quaternion.copy(target);transition=null;}
    else transition={from:world.quaternion.clone(),to:target,start:performance.now()};
    schedule();
  }
  function button(text,label,action){const b=document.createElement('button');b.type='button';b.textContent=text;b.setAttribute('aria-label',label);b.addEventListener('click',action);controls.append(b);}
  button('+','Ampliar o globo',()=>zoom(-.3));button('−','Reduzir o globo',()=>zoom(.3));button('Local atual','Centrar na localidade atual',focus);
  function at(e){const r=canvas.getBoundingClientRect();return nearbyPoints(projected,e.clientX-r.left,e.clientY-r.top,e.pointerType==='touch'?16:11);}
  function choose(point){choices.hidden=true;tip.hidden=true;onSelect(point.id);}
  canvas.addEventListener('pointerdown',e=>{if(e.button!==0)return;clearInteraction();drag={id:e.pointerId,x:e.clientX,y:e.clientY,total:0};canvas.setPointerCapture(e.pointerId);});
  canvas.addEventListener('pointermove',e=>{
    if(drag){const dx=e.clientX-drag.x,dy=e.clientY-drag.y;drag.total+=Math.hypot(dx,dy);drag.x=e.clientX;drag.y=e.clientY;rotate(dx,dy);return;}
    const found=at(e);tip.hidden=!found.length;
    if(found.length)tip.textContent=found.length>1?`${found[0].nome} e ${found.length-1} próxima(s) · clique para escolher`:`${found[0].nome} · ${found[0].iso2}`;
    canvas.style.cursor=found.length?'pointer':'grab';
  });
  canvas.addEventListener('pointerup',e=>{
    if(!drag||drag.id!==e.pointerId)return;const click=drag.total<6;drag=null;canvas.releasePointerCapture(e.pointerId);
    if(!click)return;const found=at(e);if(found.length===1){choose(found[0]);return;}
    if(found.length>1){choices.replaceChildren();for(const p of found){const b=document.createElement('button');b.type='button';b.textContent=`${p.nome} · ${p.iso2}`;b.addEventListener('click',()=>choose(p));choices.append(b);}choices.hidden=false;choices.firstElementChild.focus();}
  });
  canvas.addEventListener('pointercancel',()=>{drag=null;});canvas.addEventListener('pointerleave',()=>{tip.hidden=true;});
  host.addEventListener('keydown',e=>{if(e.key==='Escape'){choices.hidden=true;canvas.focus();}});
  canvas.addEventListener('keydown',e=>{const actions={ArrowLeft:()=>rotate(-14,0),ArrowRight:()=>rotate(14,0),ArrowUp:()=>rotate(0,-14),ArrowDown:()=>rotate(0,14),'+':()=>zoom(-.3),'=':()=>zoom(-.3),'-':()=>zoom(.3),Home:focus};if(actions[e.key]){e.preventDefault();actions[e.key]();}});
  new ResizeObserver(resize).observe(host);
  new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;if(inView)schedule();else{cancelAnimationFrame(raf);raf=0;}}).observe(host);
  document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(raf);raf=0;}else schedule();});
  reduced.addEventListener('change',()=>{if(reduced.matches&&transition){world.quaternion.copy(transition.to);transition=null;schedule();}});
  canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();cancelAnimationFrame(raf);raf=0;host.dispatchEvent(new Event('locatorfailed'));});
  return {
    catalogue(points){catalogue=points.map(p=>({...p,vector:new T.Vector3(...globePoint(p.longitude,p.latitude))}));schedule();},
    show(p){host.hidden=false;const changed=selected?.id!==p.id;selected=p;resize();if(changed)focus();else schedule();},
    hide(){host.hidden=true;cancelAnimationFrame(raf);raf=0;}
  };
}
