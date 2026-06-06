// Start odoc's bundled highlight.js on the code blocks (odoc emits them as
// <pre class="language-ocaml"> and highlights client-side). Ocsipersist has no
// ppx / client-server split, so plain OCaml highlighting is enough.
(function () {
  if (!window.hljs) return;
  if (document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", function () {
      hljs.highlightAll();
    });
  else hljs.highlightAll();
})();
