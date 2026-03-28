const STORAGE_KEY = 'sleepscape_tooltips_shown';

/** Set a tooltip on an element. */
export function applyTooltip(el: HTMLElement, text: string): void {
  el.dataset.tooltip = text;
}

/**
 * On first visit, briefly pulse all tooltips with staggered timing
 * so the user notices the controls. No-ops on repeat visits.
 */
export function runIntroTooltips(): void {
  if (localStorage.getItem(STORAGE_KEY)) return;
  localStorage.setItem(STORAGE_KEY, 'true');

  const els = document.querySelectorAll<HTMLElement>('[data-tooltip]');
  els.forEach((el, i) => {
    setTimeout(() => {
      el.classList.add('tooltip-intro');
      el.addEventListener('animationend', () => {
        el.classList.remove('tooltip-intro');
      }, { once: true });
    }, i * 300);
  });
}
