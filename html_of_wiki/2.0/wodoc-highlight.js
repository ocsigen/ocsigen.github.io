// Start odoc's bundled highlight.js on the code blocks (odoc emits them as
// <pre class="language-ocaml"> and highlights client-side). html_of_wiki's
// manual mostly shows shell/wikicreole examples in plain verbatim blocks.
(function () {
  if (!window.hljs) return;
  if (document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", function () {
      hljs.highlightAll();
    });
  else hljs.highlightAll();
})();
