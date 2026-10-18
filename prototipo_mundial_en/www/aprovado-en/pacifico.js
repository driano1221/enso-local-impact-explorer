import {ISO_CSS, figureSvg} from './vendor/anatomy/iso-kit.js';
import {PHASES,W,H,staticScene,waterScene,frontScene,windScene,surfaceGradient} from './pacifico-model.js';

const css=document.createElement('style');css.textContent=ISO_CSS;document.head.prepend(css);
const model=document.getElementById('model');
const controls=[...document.querySelectorAll('[data-phase]')];
let phase='neutral', current={...PHASES.neutral}, frame=0, earth=null;
const still=matchMedia('(prefers-reduced-motion: reduce)');
model.innerHTML=figureSvg({width:W,height:H,label:'Illustrative Pacific cross-section: westward winds, warmer water above and colder water below.',body:staticScene()+'<g id="water"></g>'+frontScene()+'<g id="wind"></g>'});
const water=document.getElementById('water'),wind=document.getElementById('wind');
function describeEarth(){
  document.querySelector('#earth-stage canvas')?.setAttribute('aria-label',`Earth globe. ${PHASES[phase].name}. ${PHASES[phase].title} Colours are illustrative. Drag horizontally or use left and right arrows to rotate; Home returns to the Pacific.`);
}
function draw(state){
  water.innerHTML=waterScene(state);wind.innerHTML=windScene(state);
  const g=surfaceGradient(state), gradient=document.getElementById('surface');
  for(const key of ['x1','x2','y1','y2'])gradient.setAttribute(key,g[key]);
  document.getElementById('warm-stop').setAttribute('offset',g.warm);
  document.getElementById('cool-stop').setAttribute('offset',g.cold);
  earth?.update(state);
}
function select(next){
  if(!Object.hasOwn(PHASES,next))return;
  cancelAnimationFrame(frame);phase=next;
  const state=PHASES[next],from={...current};
  controls.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.phase===next)));
  for(const [id,text] of Object.entries({'phase-name':state.name,'statement':state.title,'wind-detail':state.windText,'warm-detail':state.warmText,'cold-detail':state.coldText,'wind-readout':next==='nino'?'Weaker trade winds':next==='nina'?'Stronger trade winds':'East-to-west trade winds'}))document.getElementById(id).textContent=text;
  model.querySelector('svg').setAttribute('aria-label',`${state.name}. ${state.title} ${state.coldText}`);
  describeEarth();
  if(still.matches||document.hidden){current={...state};draw(current);return;}
  const start=performance.now();
  function tick(now){
    const t=Math.min(1,(now-start)/650),q=t*t*(3-2*t);
    for(const key of ['west','east','reach','wind'])current[key]=from[key]+(state[key]-from[key])*q;
    draw(current);if(t<1)frame=requestAnimationFrame(tick);
  }
  frame=requestAnimationFrame(tick);
}
controls.forEach(button=>button.addEventListener('click',()=>select(button.dataset.phase)));
function settle(){cancelAnimationFrame(frame);current={...PHASES[phase]};draw(current);}
document.addEventListener('visibilitychange',()=>{if(document.hidden)settle();});
still.addEventListener('change',()=>{if(still.matches)settle();});
draw(current);
const viewButtons=[...document.querySelectorAll('[data-view]')];
function chooseView(view){
  document.getElementById('earth-view').hidden=view!=='earth';
  document.getElementById('section-view').hidden=view!=='section';
  viewButtons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.view===view)));
}
viewButtons.forEach(b=>b.addEventListener('click',()=>chooseView(b.dataset.view)));
const focusButtons=[...document.querySelectorAll('[data-focus]')];
focusButtons.forEach(b=>b.addEventListener('click',()=>earth?.focus(Number(b.dataset.focus))));
function unavailable(){
  earth?.destroy();earth=null;chooseView('section');
  document.getElementById('earth-error').hidden=false;
  const globeButton=viewButtons.find(b=>b.dataset.view==='earth');globeButton.disabled=true;
}
document.getElementById('earth-stage').addEventListener('earth-unavailable',unavailable);
import('./terra.js').then(({createEarth})=>createEarth(document.getElementById('earth-stage'),current,view=>{
  focusButtons.forEach(b=>b.setAttribute('aria-pressed',String(view===(b.dataset.focus==='225'?'pacific':'americas'))));
  document.getElementById('orientation').textContent=view==='pacific'?'EQUATORIAL PACIFIC':view==='americas'?'THE AMERICAS AND THE PACIFIC':'EXPLORE THE PLANET';
})).then(result=>{earth=result;earth.update(current);describeEarth();}).catch(error=>{console.error('Globe unavailable:',error);unavailable();});
const sendHeight=()=>parent.postMessage({type:'enso-figure-height',height:Math.ceil(document.body.getBoundingClientRect().height)},new URL(document.baseURI).origin);
new ResizeObserver(sendHeight).observe(document.body);sendHeight();
