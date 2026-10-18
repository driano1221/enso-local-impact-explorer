// Geography is in degrees. These helpers are shared by rendering and checks.
export function globePoint(lon,lat,r=1){
  const a=lon*Math.PI/180,b=lat*Math.PI/180;
  return [r*Math.cos(b)*Math.cos(a),r*Math.sin(b),-r*Math.cos(b)*Math.sin(a)];
}
export const longitudeRotation=lon=>(270-lon)*Math.PI/180;
export const warmLongitude=reach=>150+reach*130;
export function windPoints(start,strength){
  const length=8+strength*14;
  return Array.from({length:25},(_,i)=>globePoint(start-length*i/24,13,1.065));
}
