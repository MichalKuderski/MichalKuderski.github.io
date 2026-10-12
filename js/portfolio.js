document.documentElement.classList.add('js');

const menuButton = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#navigation');
function closeMenu() {
  navigation.classList.remove('is-open');
  menuButton.setAttribute('aria-expanded', 'false');
  menuButton.textContent = 'Menu';
}
menuButton.addEventListener('click', () => {
  const expanded = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(expanded));
  menuButton.textContent = expanded ? 'Close' : 'Menu';
  navigation.classList.toggle('is-open', expanded);
});
navigation.addEventListener('click', event => {
  const link = event.target.closest('a');
  if (!link) return;
  const menuWasOpen = menuButton.getAttribute('aria-expanded') === 'true';
  closeMenu();
  if (menuWasOpen && link.hash) {
    const target = document.getElementById(link.hash.slice(1));
    target?.focus({ preventScroll: true });
  }
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') {
    closeMenu();
    menuButton.focus();
  }
});

const desktopNavigation = window.matchMedia('(min-width: 961px)');
desktopNavigation.addEventListener?.('change', event => {
  if (event.matches) closeMenu();
});

if ('IntersectionObserver' in window) {
  const links = [...navigation.querySelectorAll('a[href^="#"]')];
  const visibleSections = new Set();
  const sectionObserver = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) visibleSections.add(entry.target.id);
      else visibleSections.delete(entry.target.id);
    }
    const active = links.find(link => visibleSections.has(link.hash.slice(1)));
    for (const link of links) {
      if (link === active) link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    }
  }, { rootMargin: '-15% 0px -70% 0px', threshold: 0 });
  for (const link of links) {
    const section = document.getElementById(link.hash.slice(1));
    if (section) sectionObserver.observe(section);
  }
}

const status = document.querySelector('#code-status');
document.querySelectorAll('[data-copy]').forEach(button => {
  button.addEventListener('click', async () => {
    const code = document.getElementById(button.dataset.copy);
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(code.textContent);
      status.textContent = `${button.dataset.name} copied to clipboard.`;
      button.textContent = 'Copied';
      window.setTimeout(() => { button.textContent = 'Copy SQL'; }, 2000);
    } catch {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(code);
      selection.removeAllRanges();
      selection.addRange(range);
      status.textContent = 'SQL selected. Press Ctrl+C (Windows) or Command+C (Mac) to copy.';
    }
  });
});
document.querySelectorAll('[data-wrap]').forEach(button => {
  button.addEventListener('click', () => {
    const pre = document.getElementById(button.dataset.wrap);
    const enabled = button.getAttribute('aria-pressed') !== 'true';
    button.setAttribute('aria-pressed', String(enabled));
    button.textContent = enabled ? 'Unwrap lines' : 'Wrap lines';
    const name = button.closest('details').querySelector('summary').firstChild.textContent.trim();
    button.setAttribute('aria-label', `${enabled ? 'Unwrap' : 'Wrap'} lines in ${name}`);
    pre.classList.toggle('wrap-code', enabled);
  });
});

const emailCopy = document.querySelector('[data-copy-email]');
const contactStatus = document.querySelector('#contact-status');
emailCopy?.addEventListener('click', async () => {
  try {
    if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
    await navigator.clipboard.writeText(emailCopy.dataset.copyEmail);
    contactStatus.textContent = 'Email address copied.';
  } catch {
    const address = document.getElementById('contact-email');
    const range = document.createRange();
    range.selectNodeContents(address);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    contactStatus.textContent = 'Address selected. Press Ctrl+C (Windows) or Command+C (Mac) to copy.';
  }
});
