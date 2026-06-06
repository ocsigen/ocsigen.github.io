// Eliom-specific tweaks to odoc's bundled highlight.js (OCaml grammar).
// odoc only colours OCaml keywords/types/strings; this teaches it Eliom's ppx
// syntax so manual code blocks read better:
//   - let%client / %server / %shared get a per-side colour (yellow/blue/green),
//   - ~% client-value injections are highlighted,
//   - the name bound by let/and (function names) is highlighted.
// Loaded right after highlight.pack.js, in <head>, then highlighting is started.
(function () {
  var oc = window.hljs && hljs.getLanguage && hljs.getLanguage("ocaml");
  if (oc && oc.contains) {
    var lead =
      "(?:let|and|val|module|open|include|method|class|type|exception|fun)";
    var rules = [];
    // whole `let%client` (etc.) as one per-side token
    ["client", "server", "shared"].forEach(function (s) {
      rules.push({
        className: "eliom-" + s,
        begin: new RegExp("\\b" + lead + "%" + s + "\\b"),
      });
    });
    // bare `%client` (e.g. [%client ...], fun%client)
    ["client", "server", "shared"].forEach(function (s) {
      rules.push({ className: "eliom-" + s, begin: new RegExp("%" + s + "\\b") });
    });
    // ~%x client-value injection, and other %extensions (%rpc, %lwt, ...)
    rules.push({ className: "subst", begin: /~%[A-Za-z_][\w']*/ });
    rules.push({ className: "keyword", begin: /%[a-z]+/ });
    oc.contains.unshift.apply(oc.contains, rules);
    // the name bound by let / let%x / and -> a function/title (lookbehind may be
    // unsupported on old browsers; guard so the rest still applies)
    try {
      oc.contains.unshift({
        className: "title",
        begin: new RegExp("(?<=\\b(?:let|and)(?:%[a-z]+)?\\s+)[a-z_][\\w']*"),
      });
    } catch (e) {
      /* lookbehind unsupported: skip function-name highlighting */
    }
    hljs.registerLanguage("ocaml", function () {
      return oc;
    });
  }
  if (window.hljs) {
    if (document.readyState === "loading")
      document.addEventListener("DOMContentLoaded", function () {
        hljs.highlightAll();
      });
    else hljs.highlightAll();
  }
})();
