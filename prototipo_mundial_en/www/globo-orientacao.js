export function globeAngles(longitude,latitude){
  if(!Number.isFinite(longitude)||!Number.isFinite(latitude)||Math.abs(longitude)>180||Math.abs(latitude)>90)throw Error('Coordenadas inválidas');
  return [latitude*Math.PI/180,-Math.PI/2-longitude*Math.PI/180,0];
}
