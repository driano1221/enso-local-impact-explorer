(() => {
  const apply=theme=>{if(['light','dark'].includes(theme))document.documentElement.dataset.theme=theme;};
  try{apply(localStorage.getItem('enso-theme'));}catch{}
  addEventListener('message',event=>{
    if(event.source!==parent||event.origin!==new URL(document.baseURI).origin||event.data?.type!=='enso-theme')return;
    apply(event.data.theme);
  });
})();
