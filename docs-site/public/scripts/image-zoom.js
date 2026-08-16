/*
 * Click a screenshot to see it full size. Escape, or another click, closes it.
 *
 * Served from public/ rather than inlined so it stays cacheable and readable.
 * Delegated from the document, so it works on every page including the ones
 * generated from the capture manifest, and needs no per-image markup.
 */
(function () {
  'use strict';

  var OVERLAY_CLASS = 'dp-zoom-overlay';
  var overlay = null;
  var lastFocused = null;

  function close() {
    if (!overlay) return;
    overlay.remove();
    overlay = null;
    document.body.style.removeProperty('overflow');
    // Put focus back where the reader left it, or keyboard users lose their
    // place in the page.
    if (lastFocused && typeof lastFocused.focus === 'function') lastFocused.focus();
    lastFocused = null;
  }

  function open(img) {
    close();
    lastFocused = document.activeElement;

    overlay = document.createElement('div');
    overlay.className = OVERLAY_CLASS;
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', img.alt || 'Screenshot');
    overlay.tabIndex = -1;

    var full = document.createElement('img');
    // currentSrc resolves whatever the browser actually chose from srcset.
    full.src = img.currentSrc || img.src;
    full.alt = img.alt || '';
    overlay.appendChild(full);

    if (img.alt) {
      var caption = document.createElement('p');
      caption.className = 'dp-zoom-caption';
      caption.textContent = img.alt;
      overlay.appendChild(caption);
    }

    document.body.appendChild(overlay);
    // Stop the page scrolling behind the overlay.
    document.body.style.overflow = 'hidden';
    overlay.focus();
  }

  document.addEventListener('click', function (event) {
    if (overlay) {
      close();
      return;
    }
    var img = event.target.closest ? event.target.closest('.sl-markdown-content img') : null;
    if (!img) return;
    // Leave a linked image alone — following the link is what the author meant.
    if (img.closest('a')) return;
    event.preventDefault();
    open(img);
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') close();
  });
})();
