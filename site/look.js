// The chosen look: html[data-look], remembered in this browser only.
// The head of each page applies it before the first paint; this file wires
// the buttons and swaps the icons to the look's own app icon.
(function () {
  var looks = ['ink', 'ocean', 'forest', 'blossom'];
  function apply(look) {
    if (looks.indexOf(look) < 0) look = 'ink';
    document.documentElement.dataset.look = look;
    document.querySelectorAll('[data-look-icon]').forEach(function (img) {
      img.src = '/img/icon-' + look + '.png';
    });
    document.querySelectorAll('[data-pick]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.pick === look));
    });
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest('[data-pick]');
    if (!b) return;
    e.preventDefault();
    apply(b.dataset.pick);
    try { localStorage.setItem('look', b.dataset.pick); } catch (_) {}
  });
  apply(document.documentElement.dataset.look);
})();
