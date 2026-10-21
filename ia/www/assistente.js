(() => {
  'use strict';
  document.addEventListener('DOMContentLoaded', () => {
    const question = document.getElementById('enso_question');
    if (question) question.maxLength = 500;
    document.querySelectorAll('[data-enso-question]').forEach(button => button.addEventListener('click', () => {
      question.value = button.dataset.ensoQuestion;
      if (window.jQuery) jQuery(question).trigger('change');
      else question.dispatchEvent(new Event('change', {bubbles: true}));
      question.focus();
    }));
    if (window.Shiny) Shiny.addCustomMessageHandler('enso-ai-status', message => {
      document.getElementById('enso_ask').disabled = Boolean(message.busy);
      document.getElementById('enso-ai-status').setAttribute('aria-busy', String(Boolean(message.busy)));
    });

    const frame = document.querySelector('.pacifico-frame');
    let pending = false, timer, stopGuide = () => {};
    const guide = () => {
      if (!pending || !frame) return;
      let doc;
      try { doc = frame.contentDocument; } catch { return; }
      const controls = doc?.querySelector('.phase-controls');
      if (!controls) return;
      pending = false; clearTimeout(timer); stopGuide();
      if (!doc.getElementById('enso-guide-style')) {
        const style = doc.createElement('style'); style.id = 'enso-guide-style';
        style.textContent = '.phase-controls.enso-guide-active{outline:3px solid #de993e;outline-offset:6px;box-shadow:0 0 0 8px #eaa84920;transition:outline-color .2s;flex-wrap:wrap}.enso-guide-note{font:600 12px/1.4 "Source Sans 3",sans-serif;color:#18536c;margin:0;padding:5px 6px 7px;flex:0 0 100%;box-sizing:border-box}.enso-guide-active button{scroll-margin-top:100px}[data-theme=dark] .enso-guide-note{color:#9ed4e5}@media(prefers-reduced-motion:reduce){.phase-controls.enso-guide-active{transition:none}}';
        doc.head.append(style);
      }
      let note = doc.getElementById('enso-guide-note');
      if (!note) { note = doc.createElement('p'); note.id = 'enso-guide-note'; note.className = 'enso-guide-note'; note.setAttribute('role', 'status'); controls.prepend(note); }
      note.textContent = document.documentElement.lang.startsWith('en') ? 'Choose a phase to see what changes.' : 'Escolha uma fase para ver o que muda.';
      controls.classList.add('enso-guide-active');
      let positioning;
      const position = () => {
        if (!controls.classList.contains('enso-guide-active') || !controls.getClientRects().length) return;
        const top = window.scrollY + frame.getBoundingClientRect().top + controls.getBoundingClientRect().top - 110;
        window.scrollTo({top: Math.max(0, top), behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth'});
      };
      // Revealing the tab and loading fonts can resize the frame after the first scroll.
      const observer = new ResizeObserver(() => { cancelAnimationFrame(positioning); positioning = requestAnimationFrame(position); });
      observer.observe(frame); observer.observe(controls);
      const clear = () => { observer.disconnect(); cancelAnimationFrame(positioning); controls.classList.remove('enso-guide-active'); note.remove(); };
      stopGuide = clear;
      controls.addEventListener('click', clear, {once: true});
      timer = setTimeout(clear, 7000);
      requestAnimationFrame(() => requestAnimationFrame(() => {
        const button = controls.querySelector('[aria-pressed=true]') || controls.querySelector('button');
        button?.focus({preventScroll: true});
        position();
      }));
    };
    frame?.addEventListener('load', guide);
    document.querySelectorAll('a[href="#entender"]').forEach(link => link.addEventListener('click', event => {
      event.preventDefault(); pending = true;
      const tab = document.querySelector('#entender [data-bs-toggle="tab"]');
      tab?.click();
      const target = document.getElementById('entender');
      target.scrollIntoView({block: 'start', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth'});
      history.replaceState(null, '', '#entender');
      guide();
    }));
  });
})();
