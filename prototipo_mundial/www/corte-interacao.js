import {ISO_CSS, figureSvg} from './aprovado/vendor/anatomy/iso-kit.js';
import {PHASES,W,H,staticScene,waterScene,frontScene,windScene,surfaceGradient} from './corte-oceanico.js?v=detalhes4';

const css=document.createElement('style');css.textContent=ISO_CSS;document.head.prepend(css);
const model=document.getElementById('model');
const controls=[...document.querySelectorAll('[data-phase]')];
let phase='neutral', current={...PHASES.neutral}, frame=0;
const still=matchMedia('(prefers-reduced-motion: reduce)');
model.innerHTML=figureSvg({width:W,height:H,label:'Corte didático do Pacífico: ventos para oeste, água quente acima e água fria abaixo.',body:'<g transform="translate(-20 -35)">'+staticScene()+'<g id="water"></g>'+frontScene()+'<g id="wind"></g></g>'});
const water=document.getElementById('water'),wind=document.getElementById('wind');
function draw(state){
  water.innerHTML=waterScene(state);wind.innerHTML=windScene(state);
  const g=surfaceGradient(state), gradient=document.getElementById('surface');
  for(const key of ['x1','x2','y1','y2'])gradient.setAttribute(key,g[key]);
  document.getElementById('warm-stop').setAttribute('offset',g.warm);
  document.getElementById('cool-stop').setAttribute('offset',g.cold);

}
function select(next){
  if(!Object.hasOwn(PHASES,next))return;
  cancelAnimationFrame(frame);phase=next;
  const state=PHASES[next],from={...current};
  controls.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.phase===next)));
  for(const [id,text] of Object.entries({'phase-name':state.name,'statement':state.title,'wind-detail':state.windText,'warm-detail':state.warmText,'cold-detail':state.coldText}))document.getElementById(id).textContent=text;
  model.querySelector('svg').setAttribute('aria-label',`${state.name}. ${state.title} ${state.coldText}`);

  if(still.matches||document.hidden){current={...state};draw(current);return;}
  const start=performance.now();
  function tick(now){
    const t=Math.min(1,(now-start)/800),q=t*t*(3-2*t);
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
const sendHeight=()=>parent.postMessage({type:'enso-figure-height',height:Math.ceil(document.body.getBoundingClientRect().height)},new URL(document.baseURI).origin);
new ResizeObserver(sendHeight).observe(document.body);sendHeight();
