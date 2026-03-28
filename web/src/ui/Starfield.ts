/**
 * 55 twinkling stars rendered as a CSS overlay behind the UI.
 */
export class Starfield {
  private el: HTMLElement;

  constructor() {
    this.el = document.createElement('div');
    this.el.className = 'starfield';
    this.el.setAttribute('aria-hidden', 'true');

    for (let i = 0; i < 55; i++) {
      const star = document.createElement('div');
      star.className = 'star';
      star.style.left = `${Math.random() * 100}%`;
      star.style.top = `${Math.random() * 100}%`;
      const size = 1 + Math.random() * 1.5;
      star.style.width = `${size}px`;
      star.style.height = `${size}px`;
      star.style.animationDelay = `${Math.random() * 6}s`;
      star.style.animationDuration = `${3 + Math.random() * 5}s`;
      this.el.appendChild(star);
    }

    document.body.appendChild(this.el);
  }
}
