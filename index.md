# Next-level full-stack development

## Write your app once — deploy on Web, Android, iOS

## Unique multi-tier architecture: client and server in a single program

## Type-safe from database to UI — catch errors before they happen

## Runs natively in WebAssembly (with JavaScript fallback)

[Get started now\!](/tuto/latest/basics.html)

- [![Be Sport](/img/besport.svg)](https://www.dailymotion.com/video/x82alm8)
- [![Tarides](/img/tarides.svg)](https://tarides.com)
- [![Jane Street](/img/janestreet.svg)](https://www.janestreet.com)
- [![Université Paris Diderot](/img/diderot.png)](http://www.univ-paris-diderot.fr)
- [![CNRS](/img/cnrs.png)](http://www.cnrs.fr)
- [![IRIF](/img/irif.svg)](http://www.irif.fr)
- [![IRILL](/img/irill.png)](http://www.irill.org)
- [![Inria](/img/inria.png)](http://www.inria.fr)
- [![Systematic](/img/systematic.png)](http://www.systematic-paris-region.org)

## Eliom

### Client and server code that compile together

Eliom lets you write **client and server code in the same file, and as a single program**. The compiler checks that they stay consistent — **no more broken APIs**\!

A single codebase compiles to a **Web app** and to **mobile apps** for iOS and Android.

![Multi-tier](/img/multitier-multiplatform.svg)

## Js\_of\_ocaml / Wasm\_of\_ocaml

### Your OCaml code, running in the browser at near-native speed

Compile any OCaml program to **JavaScript** or **WebAssembly**. WASM delivers near-native performance; JS ensures compatibility with all browsers.

Works directly from OCaml bytecode — **use any OCaml library without recompiling**. Seamless interop with JavaScript libraries.

```ocaml
let fib num =
  let rec aux num prec2 prec =
    if num = 0
    then prec
    else
      aux (num - 1) prec (prec + prec2)
  in aux num 1 1
```

```javascript
function fib(num)
 {var num$0=num,prec2=1,prec=1;
  for(;;)
   {if(0 === num$0)return prec;
    var
     prec$0=prec + prec2 | 0,
     num$1=num$0 - 1 | 0,
     num$0=num$1,
     prec2=prec,
     prec=prec$0;
     continue}}
```

```javascript
function(d){var b=d,c=1,a=1;for(;;){if(0===b)return a;var b=b-1|0,e=a+c|0,c=a,a=e;continue}};
```

➔

➔

## Main projects

### [Js\_of\_ocaml](/js_of_ocaml/)

Compile OCaml to JS and WebAssembly. Run in any browser.

### [Eliom](/eliom/)

Write client and server as one program. Deploy to Web and mobile.

### [Server](/ocsigenserver/)

Production-ready Web server with native OCaml integration.

### [Lwt](/lwt/)

Concurrent programming made simple — no callback hell.

### [Tyxml](/tyxml/)

Type-safe HTML/SVG generation. Invalid markup won't compile.

### [Ocsigen Toolkit](/ocsigen-toolkit/)

Ready-to-use UI widgets for Web and mobile apps.

### [Start](/ocsigen-start/)

Complete starter app with users, notifications, and mobile support.

## From the blog

 [More posts →](/blog/)
