// Pure rules shared by the renderer and tests. Pick only visible catalogue points.
export function visiblePoint(v, cameraDistance){return v.z > 1 / cameraDistance + .002;}
export function nearbyPoints(points,x,y,radius=11){
  return points.map(p=>({...p,d:Math.hypot(p.x-x,p.y-y)})).filter(p=>p.d<=radius).sort((a,b)=>a.d-b.d);
}
export function zoomDistance(distance,delta){return Math.max(2.2,Math.min(5,distance+delta));}
