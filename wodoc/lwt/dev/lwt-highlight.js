// Lwt tweaks to odoc's bundled highlight.js (OCaml grammar).
// odoc emits manual/example code blocks as <pre class="language-ocaml"> and only
// colours base OCaml; this teaches it Lwt's ppx syntax so examples read better:
//   - the ppx extension points (let%lwt, match%lwt, [%lwt ...], try%lwt, …),
//   - the binding operators (let*, and*, let+) used by Lwt.Syntax,
//   - the name bound by let/and (function names).
// Loaded right after highlight.pack.js, in <head>, then highlighting is started.
(function () {
  var oc = window.hljs && hljs.getLanguage && hljs.getLanguage("ocaml");
  if (oc && oc.contains) {
    var rules = [];
    // ppx extension points: let%lwt, match%lwt, try%lwt, [%lwt ...]
    rules.push({ className: "keyword", begin: /%[a-z]+/ });
    // binding operators from Lwt.Syntax: let*, and*, let+, and+
    rules.push({ className: "keyword", begin: /\b(let|and)[*+]/ });
    oc.contains.unshift.apply(oc.contains, rules);
    // the name bound by let / and -> highlight as a function/title (lookbehind
    // may be unsupported on old browsers; guard so the rest still applies)
    try {
      oc.contains.unshift({
        className: "title",
        begin: new RegExp("(?<=\\b(?:let|and)(?:%[a-z]+|[*+])?\\s+)[a-z_][\\w']*"),
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
