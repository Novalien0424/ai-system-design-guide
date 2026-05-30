/* Reliable Mermaid rendering for this mirror.
 *
 * Material for MkDocs loads mermaid.js from its CDN, but its automatic render can
 * miss the first paint — a race between the async CDN import and Material's
 * `document$` hook, especially with navigation.instant. mermaid.run() itself works
 * fine, so this polls for the loaded library and issues a single render pass over
 * any unprocessed `.mermaid` blocks, on initial load and on each instant-nav swap.
 * Idempotent: the [data-processed] guard means it never double-renders. */
(function () {
  function kick() {
    var tries = 0;
    var id = setInterval(function () {
      var m = window.mermaid;
      if (m && typeof m.run === "function") {
        clearInterval(id);
        var nodes = document.querySelectorAll(".mermaid:not([data-processed])");
        if (nodes.length) {
          try { m.run({ nodes: nodes }); } catch (e) { /* mermaid logs its own errors */ }
        }
      } else if (++tries > 75) {
        clearInterval(id); // give up after ~15s; library never loaded
      }
    }, 200);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", kick);
  } else {
    kick();
  }

  // Material instant-navigation: re-render on every client-side page swap.
  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(function () { setTimeout(kick, 0); });
  }
})();
