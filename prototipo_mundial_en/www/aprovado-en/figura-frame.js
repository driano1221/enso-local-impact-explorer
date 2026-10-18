// A figura local informa a própria altura para evitar rolagem dentro da rolagem.
window.addEventListener('message', e => {
  if (e.origin !== location.origin || e.data?.type !== 'enso-figure-height' || !Number.isFinite(e.data.height)) return;
  const frame = [...document.querySelectorAll('iframe')].find(f => f.contentWindow === e.source);
  if (frame) frame.style.height = Math.max(200,Math.min(10000,e.data.height+4))+'px';
});
