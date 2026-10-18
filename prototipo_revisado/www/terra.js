import * as T from './vendor/three/three.module.min.js';
import {globePoint,longitudeRotation,warmLongitude,windPoints} from './terra-geometry.js';

// A geographic illustration. Thermal colours, lighting and wind lengths are qualitative.
export async function createEarth(host,initial,onView){
  const response=await fetch('terra-geografia.json');
  if(!response.ok)throw new Error('Não foi possível carregar os contornos da Terra.');
  const polygons=await response.json();
  const renderer=new T.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});
  renderer.setPixelRatio(Math.min(devicePixelRatio,2));
  renderer.setClearColor(0,0);renderer.outputColorSpace=T.SRGBColorSpace;
  renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
  const canvas=renderer.domElement;canvas.tabIndex=0;canvas.setAttribute('role','img');
  canvas.setAttribute('aria-label','Globo terrestre. Pacífico em destaque. Arraste na horizontal ou use as setas esquerda e direita para girar. Home volta ao Pacífico.');
  host.replaceChildren(canvas);
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(32,1,.1,30);
  camera.position.set(0,.65,4.9);camera.lookAt(0,.18,0);
  scene.add(new T.HemisphereLight(0xe7f2ef,0x77949a,1.65));
  const key=new T.DirectionalLight(0xffffff,2.2);key.position.set(-3,5,4);scene.add(key);
  const rim=new T.DirectionalLight(0x9cd2e2,1.4);rim.position.set(3,1,-2);scene.add(rim);
  const world=new T.Group();world.position.y=.3;scene.add(world);
  const textureCanvas=document.createElement('canvas');textureCanvas.width=2048;textureCanvas.height=1024;
  const ctx=textureCanvas.getContext('2d');
  ctx.fillStyle='#326678';ctx.fillRect(0,0,2048,1024);
  const maskCanvas=document.createElement('canvas');maskCanvas.width=2048;maskCanvas.height=1024;
  const mask=maskCanvas.getContext('2d');mask.fillStyle='#000';mask.fillRect(0,0,2048,1024);
  function land(context,fill){
    context.fillStyle=fill;
    for(const poly of polygons){context.beginPath();for(const ring of poly){ring.forEach(([lon,lat],i)=>{const x=(lon+180)/360*2048,y=(90-lat)/180*1024;i?context.lineTo(x,y):context.moveTo(x,y);});context.closePath();}context.fill('evenodd');}
  }
  land(ctx,'#c8d4be');land(mask,'#fff');
  ctx.strokeStyle='rgba(211,236,230,.20)';ctx.lineWidth=.7;
  for(let lon=-180;lon<=180;lon+=30){const x=(lon+180)/360*2048;ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,1024);ctx.stroke();}
  for(let lat=-60;lat<=60;lat+=30){const y=(90-lat)/180*1024;ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(2048,y);ctx.stroke();}
  ctx.fillStyle='rgba(213,235,230,.55)';ctx.textAlign='center';ctx.font='500 20px system-ui';
  const pacificX=(215-180)/360*2048,pacificY=(90+25)/180*1024;
  ctx.fillText('O C E A N O',pacificX,pacificY-12);ctx.fillText('P A C Í F I C O',pacificX,pacificY+17);
  const texture=new T.CanvasTexture(textureCanvas);texture.colorSpace=T.SRGBColorSpace;texture.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());
  const landMask=new T.CanvasTexture(maskCanvas);
  const reach={value:warmLongitude(initial.reach)};
  const material=new T.MeshPhongMaterial({map:texture,shininess:23,specular:0x214450});
  material.onBeforeCompile=shader=>{
    shader.uniforms.ensoReach=reach;shader.uniforms.landMask={value:landMask};
    shader.uniforms.ensoWarm={value:new T.Color('#df9366')};shader.uniforms.ensoCold={value:new T.Color('#4c9ab8')};
    shader.fragmentShader='uniform float ensoReach; uniform sampler2D landMask; uniform vec3 ensoWarm; uniform vec3 ensoCold;\n'+shader.fragmentShader;
    shader.fragmentShader=shader.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
      float longitude = mod(vMapUv.x * 360.0 + 180.0, 360.0);
      float latitude = (vMapUv.y - 0.5) * 180.0;
      float band = (1.0-smoothstep(3.0,8.5,abs(latitude))) * smoothstep(135.0,150.0,longitude) * (1.0-smoothstep(275.0,285.0,longitude));
      float isOcean = 1.0-texture2D(landMask,vMapUv).r;
      float cool = smoothstep(ensoReach-12.0,ensoReach+22.0,longitude);
      diffuseColor.rgb = mix(diffuseColor.rgb,mix(ensoWarm,ensoCold,cool),band*isOcean*.95);`);
  };
  world.add(new T.Mesh(new T.SphereGeometry(1,112,72),material));
  const winds=new T.Group();world.add(winds);
  const windMaterial=new T.MeshStandardMaterial({color:0xe3e7d6,roughness:.52,metalness:.12});
  const point=(lon,lat,r=1)=>new T.Vector3(...globePoint(lon,lat,r));
  function updateWinds(strength){
    while(winds.children.length){const obj=winds.children[0];winds.remove(obj);obj.geometry.dispose();}
    for(const start of [190,231,272]){
      const points=windPoints(start,strength).map(p=>new T.Vector3(...p));
      const curve=new T.CatmullRomCurve3(points);
      const shaft=new T.Mesh(new T.TubeGeometry(curve,28,.0065,7,false),windMaterial);winds.add(shaft);
      const tip=new T.Mesh(new T.ConeGeometry(.021,.055,16),windMaterial);
      const last=points.at(-1),direction=last.clone().sub(points.at(-2)).normalize();
      tip.position.copy(last);tip.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),direction);winds.add(tip);
    }
  }
  // The plinth is a physical display support, with no climatic meaning.
  const porcelain=new T.MeshStandardMaterial({color:0xe2e8dc,metalness:.10,roughness:.44});
  const steel=new T.MeshStandardMaterial({color:0x91aaa6,metalness:.58,roughness:.35});
  const dark=new T.MeshStandardMaterial({color:0x47636b,metalness:.38,roughness:.45});
  function turned(profile,mat,y){const mesh=new T.Mesh(new T.LatheGeometry(profile.map(([r,h])=>new T.Vector2(r,h)),96),mat);mesh.position.y=y;scene.add(mesh);return mesh;}
  turned([[0,0],[.61,0],[.65,.018],[.65,.07],[.61,.092],[0,.092]],porcelain,-1.07);
  turned([[.647,0],[.654,.004],[.654,.013],[.647,.017]],steel,-1.045);
  turned([[0,0],[.22,0],[.23,.015],[.22,.04],[.12,.07],[.085,.11],[.085,.21],[0,.21]],dark,-.978);
  const meridian=new T.Mesh(new T.TorusGeometry(1.085,.012,10,160),steel);meridian.position.y=.3;meridian.rotation.y=.24;scene.add(meridian);
  for(const y of [-.787,1.36])turned([[0,0],[.027,0],[.033,.011],[.027,.031],[0,.035]],steel,y);
  const baseTicks=[];for(let i=0;i<72;i++){const angle=i*Math.PI/36,r0=i%6===0?.56:.59,r1=.617;baseTicks.push(new T.Vector3(Math.sin(angle)*r0,-.975,Math.cos(angle)*r0),new T.Vector3(Math.sin(angle)*r1,-.975,Math.cos(angle)*r1));}
  scene.add(new T.LineSegments(new T.BufferGeometry().setFromPoints(baseTicks),new T.LineBasicMaterial({color:0x91a19b,transparent:true,opacity:.7})));
  const shadowCanvas=document.createElement('canvas');shadowCanvas.width=shadowCanvas.height=128;const sc=shadowCanvas.getContext('2d');const gradient=sc.createRadialGradient(64,64,5,64,64,64);gradient.addColorStop(0,'rgba(37,59,63,.25)');gradient.addColorStop(.55,'rgba(37,59,63,.12)');gradient.addColorStop(1,'rgba(37,59,63,0)');sc.fillStyle=gradient;sc.fillRect(0,0,128,128);
  const shadow=new T.Mesh(new T.PlaneGeometry(2.5,2.5),new T.MeshBasicMaterial({map:new T.CanvasTexture(shadowCanvas),transparent:true,depthWrite:false}));shadow.rotation.x=-Math.PI/2;shadow.position.y=-1.08;scene.add(shadow);
  let lon=225,frame=0,inView=true,destroyed=false,drag=null,focusTarget=null;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  function render(){if(!destroyed&&inView&&!document.hidden)renderer.render(scene,camera);}
  function resize(){const {width,height}=host.getBoundingClientRect();if(!width||!height)return;camera.aspect=width/height;camera.updateProjectionMatrix();renderer.setSize(width,height,false);render();}
  function pose(value){lon=value;world.rotation.y=longitudeRotation(lon);world.updateMatrixWorld();render();}
  function finishFocus(){cancelAnimationFrame(frame);if(focusTarget!==null){pose(focusTarget);focusTarget=null;}}
  function focus(target){cancelAnimationFrame(frame);const from=lon,diff=((target-from+540)%360)-180;focusTarget=from+diff;
    onView?.(target===225?'pacific':target===285?'americas':'free');
    if(reduced.matches||document.hidden||!inView){finishFocus();return;}
    const start=performance.now();function tick(now){const t=Math.min(1,(now-start)/850),q=t*t*(3-2*t);pose(from+diff*q);if(t<1)frame=requestAnimationFrame(tick);else focusTarget=null;}frame=requestAnimationFrame(tick);
  }
  canvas.addEventListener('pointerdown',e=>{if(e.button!==0)return;cancelAnimationFrame(frame);focusTarget=null;drag={x:e.clientX,y:e.clientY,lon,active:false};});
  canvas.addEventListener('pointermove',e=>{if(!drag)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(!drag.active){if(Math.abs(dy)>8&&Math.abs(dy)>Math.abs(dx)){drag=null;return;}if(Math.abs(dx)<6)return;drag.active=true;canvas.setPointerCapture(e.pointerId);}onView?.('free');pose(drag.lon-dx*.3);});
  const end=()=>{drag=null;};canvas.addEventListener('pointerup',end);canvas.addEventListener('pointercancel',end);canvas.addEventListener('lostpointercapture',end);
  canvas.addEventListener('keydown',e=>{if(e.key==='Home'){e.preventDefault();focus(225);}else if(['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();cancelAnimationFrame(frame);focusTarget=null;onView?.('free');pose(lon+(e.key==='ArrowLeft'?-15:15));}});
  canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();cancelAnimationFrame(frame);host.dispatchEvent(new CustomEvent('earth-unavailable'));});
  const observer=new ResizeObserver(resize);observer.observe(host);
  const visible=new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;if(inView)render();else finishFocus();});visible.observe(host);
  const visibility=()=>{if(document.hidden)finishFocus();else render();};document.addEventListener('visibilitychange',visibility);
  const motion=()=>{if(reduced.matches)finishFocus();};reduced.addEventListener('change',motion);
  updateWinds(initial.wind);pose(lon);resize();
  return {
    update(state){reach.value=warmLongitude(state.reach);updateWinds(state.wind);render();}, focus,
    destroy(){destroyed=true;cancelAnimationFrame(frame);observer.disconnect();visible.disconnect();document.removeEventListener('visibilitychange',visibility);reduced.removeEventListener('change',motion);const materials=new Set();scene.traverse(obj=>{obj.geometry?.dispose();if(obj.material)materials.add(obj.material);});materials.forEach(m=>{m.map?.dispose();m.dispose();});landMask.dispose();renderer.dispose();}
  };
}
