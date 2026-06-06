// Js_of_ocaml tweaks to odoc's bundled highlight.js (OCaml grammar).
// odoc emits manual code blocks as <pre class="language-ocaml"> and only colours
// base OCaml; this teaches it Js_of_ocaml's ppx syntax so examples read better:
//   - the JS object ppx extensions (object%js, new%js, [%js], val%js, method%js),
//   - the method/property access operators (obj##meth, obj##.prop),
//   - the name bound by let/and (function names).
// Loaded right after highlight.pack.js, in <head>, then highlighting is started.
(function () {
  var oc = window.hljs && hljs.getLanguage && hljs.getLanguage("ocaml");
  if (oc && oc.contains) {
    var rules = [];
    // ppx extension points: object%js, new%js, val%js, method%js, [%js ...]
    rules.push({ className: "keyword", begin: /%[a-z]+/ });
    // method / property access operators: obj##meth, obj##.prop, obj##.prop :=
    rules.push({ className: "operator", begin: /##\.?/ });
    oc.contains.unshift.apply(oc.contains, rules);
    // the name bound by let / and -> highlight as a function/title (lookbehind
    // may be unsupported on old browsers; guard so the rest still applies)
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
