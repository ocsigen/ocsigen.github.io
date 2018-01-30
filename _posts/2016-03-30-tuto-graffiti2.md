---
title: Ocsigen&#58; step by step tutorial for client-server Web application (2/2)
layout: default
author: Ocsigen team
authorurl: http://ocsigen.org
---

This is the end of the tutorial about writing a collaborative Web drawing
in OCaml. Have a look at
[the full tutorial](http://ocsigen.org/tuto/manual/application)
if you haven't read the first part or if you want a version with full
colors and links.

In the last part, we've seen how to create a client-server Web application
in OCaml. The server generates a Web page and sends it together with an
OCaml program (compiled to JavaScript) to the browser.

We will now see how to draw on the canvas, program mouse events with Lwt,
and do server to client communication on a bus.

## Collaborative drawing application                           

### Drawing on a canvas

We now want to draw something on the page using an HTML5 canvas. The
drawing primitive is defined in the client-side function called
`draw` that just draws a line between two given points in a canvas.

To start our collaborative drawing application, we define another
client-side function `init_client`, which just draws a single
line for now.

Here is the (full) new version of the program:

{% highlight ocaml %}
[%%shared
  (* Modules opened in the shared-section are available in client-
     and server-code *)
  open Eliom_content.Html5.D
  open Lwt
]

module Graffiti_app =
  Eliom_registration.App (
    struct
      let application_name = "graffiti"
    end)
    
let%shared width = 700
let%shared height = 400

let%client draw ctx ((r, g, b), size, (x1, y1), (x2, y2)) =
  let color = CSS.Color.string_of_t (CSS.Color.rgb r g b) in
  ctx##.strokeStyle := (Js.string color);
  ctx##.lineWidth := float size;
  ctx##beginPath;
  ctx##(moveTo (float x1) (float y1));
  ctx##(lineTo (float x2) (float y2));
  ctx##stroke

let canvas_elt =
  canvas ~a:[a_width width; a_height height]
    [pcdata "your browser doesn't support canvas"]

let page () =
  (html
     (head (title (pcdata "Graffiti")) [])
     (body [h1 [pcdata "Graffiti"];
            canvas_elt]))

let%client init_client () =
  let canvas = Eliom_content.Html5.To_dom.of_canvas ~%canvas_elt in
  let ctx = canvas##(getContext (Dom_html._2d_)) in
  ctx##.lineCap := Js.string "round";
  draw ctx ((0, 0, 0), 12, (10, 10), (200, 100))

let main_service =
  Graffiti_app.register_service ~path:[""] ~get_params:Eliom_parameter.unit
    (fun () () ->
       (* Cf. section "Client side side-effects on the server" *)
       let _ = [%client (init_client () : unit) ] in
       Lwt.return (page ()))
{% endhighlight %}

### JavaScript datatypes in OCaml

  Here we use the function `Js.string`
  from Js_of_ocaml's library to convert an OCaml string
  into a JS string.

### Client side side-effect on the server

  What sounds a bit weird at first, is a very convenient practice for
  processing request in a client-server application: If a client value
  is created while processing a request, it will be evaluated on the
  client once it receives the response and the document is created;
  the corresponding side effects are then executed.
  For example, the line
{% highlight ocaml %}
    let _ = [%client (init_client () : unit) ] in
    ...
{% endhighlight %}

creates a client value for the sole purpose of performing side
  effects on the client.  The client value can also be named (as
  opposed to ignored via `_`), thus enabling server-side
  manipulation of client-side values (see below).

### Single user drawing application

**(Lwt, Mouse events with Lwt)**

We now want to catch mouse events to draw lines with the mouse like
with the *brush* tools of any classical drawing application. One
solution would be to mimic typical JavaScript code in OCaml; for
example by using function `Dom_events.listen`
that is the Js_of_ocaml's equivalent of
`addEventListener`. However, this solution is at least as verbose
as the JavaScript equivalent, hence not satisfactory. Js_of_ocaml's
library provides a much easier way to do that with the help of Lwt.

Replace the `init_client` of the previous example by the
following piece of code, then compile and draw!

{% highlight ocaml %}
let%client init_client () =

  let canvas = Eliom_content.Html5.To_dom.of_canvas ~%canvas_elt in
  let ctx = canvas##(getContext (Dom_html._2d_)) in
  ctx##.lineCap := Js.string "round";

  let x = ref 0 and y = ref 0 in

  let set_coord ev =
    let x0, y0 = Dom_html.elementClientPosition canvas in
    x := ev##.clientX - x0; y := ev##.clientY - y0
  in

  let compute_line ev =
    let oldx = !x and oldy = !y in
    set_coord ev;
    ((0, 0, 0), 5, (oldx, oldy), (!x, !y))
  in

  let line ev = draw ctx (compute_line ev); Lwt.return () in

  Lwt.async (fun () ->
    let open Lwt_js_events in
    mousedowns canvas
      (fun ev _ ->
         set_coord ev; line ev >>= fun () ->
           Lwt.pick
             [mousemoves Dom_html.document (fun x _ -> line x);
	      mouseup Dom_html.document >>= line]))
{% endhighlight %}

We use two references `x` and `y` to record the last mouse
position.  The function `set_coord` updates those references from
mouse event data.  The function `compute_line` computes the
coordinates of a line from the initial (old) coordinates to the new
coordinates--the event data sent as a parameter.

The last four lines of code implement the event-handling loop.  They
can be read as follows: for each `mousedown` event on the canvas,
do `set_coord`, then `line` (this will draw a dot), then
behave as the `first` of the two following lines that terminates:

- For each mousemove event on the document, call `line` (never
  terminates)
- If there is a mouseup event on the document, call `line`.

### More on Lwt

Functions in Eliom and Js_of_ocaml which do not implement just a
computation or direct side effect, but rather wait for user activity,
or file system access, or need a unforseeable amount of time to return
are defined *with Lwt*; instead of returning a value of type `a`
they return an Lwt thread of type `a Lwt.t`.

The only way to use the result of such functions (ones that return
values in the *Lwt monad*), is to use `Lwt.bind`.

{% highlight ocaml %}
Lwt.bind : 'a Lwt.t -> ('a -> 'b Lwt.t) -> 'b Lwt.t
{% endhighlight %}

It is convenient to define an infix operator like this:
{% highlight ocaml %}
let (>>=) = Lwt.bind
{% endhighlight %}

Then the code

{% highlight ocaml %}
f () >>= fun x ->
{% endhighlight %}

is conceptually similar to

{% highlight ocaml %}
let x = f () in
{% endhighlight %}

but only for functions returning a value in the Lwt monad.

For more clarity, there is a syntax extension for Lwt, defining
`let%lwt` to be used instead of `let` for Lwt functions:
{% highlight ocaml %}
let%lwt x = f () in
{% endhighlight %}

`Lwt.return` creates a terminated thread from a value: `Lwt.return : 'a -> 'a Lwt.t` Use it when you must
return something in the Lwt monad (for example in a service handler,
or often after a `Lwt.bind`).

#### Why Lwt?

An Eliom application is a cooperative program, as the server must be
able to handle several requests at the same time.  Ocsigen is using
cooperative threading instead of the more widely used preemptive
threading paradigm. It means that no scheduler will interrupt your
functions whenever it wants. Switching from one thread to another is
done only when there is a *cooperation point*.

We will use the term *cooperative functions* to identify functions
implemented in cooperative way, that is: if something takes
(potentially a long) time to complete (for example reading a value
from a database), they insert a cooperation point to let other threads
run.  Cooperative functions return a value in the Lwt monad
(that is, a value of type `'a Lwt.t` for some type `'a`).

`Lwt.bind` and `Lwt.return` do not introduce cooperation points.

In our example, the function `Lwt_js_events.mouseup` may introduce
a cooperation point, because it is unforseeable when this event
happens. That's why it returns a value in the Lwt monad.

Using cooperative threads has a huge advantage: given that you know
precisely where the cooperation points are, *you need very few
mutexes* and you have *very low risk of deadlocks*!

Using Lwt is very easy and does not cause trouble, provided you never
use *blocking functions* (non-cooperative functions).  *Blocking
functions can cause the entre server to hang!* Remember:

- Use the functions from module `Lwt_unix` instead of module
 `Unix`,
- Use cooperative database libraries (like PG'Ocaml for Lwt),
- If you want to use a non-cooperative function, detach it in another
  preemptive thread using `Lwt_preemptive.detach`,
- If you want to launch a long-running computation, manually insert
  cooperation points using `Lwt_unix.yield`,
- `Lwt.bind` does not introduce any cooperation point.


### Handling events with Lwt

  The module `Lwt_js_events`
  allows easily defining event listeners using Lwt.  For example,
  `Lwt_js_events.click` takes a
  DOM element and returns an Lwt thread that will wait until a click
  occures on this element.

  Functions with an ending "s" (`Lwt_js_events.clicks`,
  `Lwt_js_events.mousedowns`, ...) start again waiting after the
  handler terminates.

  `Lwt.pick` behaves as the first thread
  in the list to terminate, and cancels the others.

## Collaborative drawing application

**(Client server communication)**

In order to see what other users are drawing, we now want to do the
following:

- Send the coordinates to the server when the user draw a line, then
- Dispatch the coordinates to all connected users.

We first declare a type, shared by the server and the client,
describing the color (as RGB values) and coordinates of drawn lines.

{% highlight ocaml %}
[%%shared
  type messages =
    ((int * int * int) * int * (int * int) * (int * int))
    [@@deriving json]
]
{% endhighlight %}

We annotate the type declaration with `[@@deriving json]` to allow
type-safe deserialization of this type. Eliom forces you to use this
in order to avoid server crashes if a client sends corrupted data.
This is defined using a JSON plugin for
[ppx_deriving](https://github.com/whitequark/ppx_deriving), which you
need to install. You need to do that for each type of data sent by the
client to the server.  This annotation can only be added on types
containing exclusively basic types, or other types annotated with
`[@@deriving json]`.

Then we create an Eliom bus to broadcast drawing events to all client
with the function `Eliom_bus.create`.
This function take as parameter the type of
values carried by the bus.

{% highlight ocaml %}
let bus = Eliom_bus.create [%derive.json: messages]
{% endhighlight %}

To write draw commands into the bus, we just replace the function
`line` in `init_client` by:

{% highlight ocaml %}
let line ev =
  let v = compute_line ev in
  let _ = Eliom_bus.write ~%bus v in
  draw ctx v;
  Lwt.return () in
{% endhighlight %}

Finally, to interpret the draw orders read on the bus, we add the
following line at the end of function `init_client`:

{% highlight ocaml %}
  Lwt.async (fun () -> Lwt_stream.iter (draw ctx) (Eliom_bus.stream ~%bus))
{% endhighlight %}

Now you can try the program using two browser windows to see that the
lines are drawn on both windows.

### Communication channels

  Eliom provides multiple ways for the server to send unsolicited data
  to the client:

- `Eliom_bus.t` are broadcasting channels where
  client and server can participate (see also <<a_api project="eliom"
  subproject="client" | type Eliom_bus.t >> in the client
  API).
- `Eliom_react` allows sending
  [React events](http://erratique.ch/software/react/doc/React) from
  the server to the client, and conversely.
- `Eliom_comet.Channel.t` are one-way communication channels
  allowing finer-grained control. It allows sending `Lwt_stream`
  to the client.
  `Eliom_react` and `Eliom_bus` are implemented over
  `Eliom_coment`.

  It is possible to control the idle behaviour with module
  `Eliom_comet.Configuration`.

## Color and size of the brush

**(Widgets with Ocsigen-widgets)**

In this section, we add a color picker and slider to choose the size
of the brush. For the colorpicker we used a widget available in
`Ocsigen-widgets`.

To install Ocsigen widgets, do:

```
opam pin add ocsigen-widgets https://github.com/ocsigen/ocsigen-widgets.git
opam install ocsigen-widgets
```



In `Makefile.options`, created by Eliom's distillery, add
`ocsigen-widgets.client` to the
`CLIENT_PACKAGES`:

```
CLIENT_PACKAGES := ... ocsigen-widgets.client
```


To create the widget, we add the following code in the
`init_client` immediately after canvas configuration:

{% highlight ocaml %}
(* Color of the brush *)
let colorpicker = Ow_color_picker.create ~width:150 () in
Ow_color_picker.append_at (Dom_html.document##.body) colorpicker;
Ow_color_picker.init_handler colorpicker;
{% endhighlight %}

We subsequently add a simple HTML5 slider to change the size of the
brush. Near the `canvas_elt` definition, simply add the following
code:

{% highlight ocaml %}
let slider =
  Eliom_content.Html5.D.Form.input
    ~a:[
      Html5.D.a_id "slider";
      Html5.D.a_input_min 1.;
      Html5.D.a_input_max 80.
    ]
    ~input_type:`Range
    Html5.D.Form.int
{% endhighlight %}

`Form.int` is a typing information telling that this input takes
an integer value. This kind of input can only be associated to
services taking an integer as parameter.

We then add the slider to the page body, as follows:

{% highlight ocaml %}
let page =
  (html
    (head (title (pcdata "Graffiti")) [])
    (body [h1 [pcdata "Graffiti"];
           canvas_elt;
           div [slider]] ))
{% endhighlight %}

To change the size and the color of the brush, we replace the last
line of the function `compute_line` in `init_client` by:

{% highlight ocaml %}
let rgb = Ow_color_picker.get_rgb colorpicker in
let size_slider = Eliom_content.Html5.To_dom.of_input ~%slider in
let size = int_of_string (Js.to_string size_slider##.value) in
(rgb, size, (oldx, oldy), (!x, !y))
{% endhighlight %}

Finally, we need to add a stylesheet in the headers of our page. To
easily create the `head` HTML element, we use the function
`Eliom_tools.F.head`:

{% highlight ocaml %}
let page =
  html
    (Eliom_tools.F.head ~title:"Graffiti"
       ~css:[
         ["css";"graffiti.css"];]
      ~js:[] ())
    (body [h1 [pcdata "Graffiti"]; canvas_elt; div [slider]])
{% endhighlight %}

You need to install the corresponding stylesheets and images into your
project. The stylesheet files should go to the directory
`static/css`.
File [graffiti.css](http://ocsigen.org/tuto/files/tutorial/static/css/graffiti.css) is a custom-made CSS file.

You can then test your application (`make test.byte`).

### Ocsigen-widgets

  Ocsigen-widgets is a Js_of_ocaml library providing useful widgets
  for your Eliom applications. You can use it for building complex
  user interfaces.


## Sending the initial image

**(Services sending other data types)**

To finish the first part of the tutorial, we want to save the current
drawing on server side and send the current image when a new user
arrives. To do that, we will use the
[Cairo binding](http://www.cairographics.org/cairo-ocaml/) for OCaml.

For using Cairo, first, make sure that it is installed (it is
available as `cairo2` via OPAM). Second, add it to the
`SERVER_PACKAGES` in your `Makefile.options`: `SERVER_PACKAGES := ... cairo2`

The `draw_server` function below is the equivalent of the
`draw` function on the server side and the `image_string`
function outputs the PNG image in a string.

{% highlight ocaml %}
let draw_server, image_string =

  let surface = Cairo.Image.create Cairo.Image.ARGB32 ~width ~height in
  let ctx = Cairo.create surface in

  let rgb_floats_from_ints (r, g, b) =
    float r /. 255., float g /. 255., float b /. 255. in

  ((fun (rgb, size, (x1, y1), (x2, y2)) ->

    (* Set thickness of brush *)
    Cairo.set_line_width ctx (float size) ;
    Cairo.set_line_join ctx Cairo.JOIN_ROUND ;
    Cairo.set_line_cap ctx Cairo.ROUND ;
    let r, g, b =  rgb_floats_from_ints rgb in
    Cairo.set_source_rgb ctx ~r ~g ~b ;

    Cairo.move_to ctx (float x1) (float y1) ;
    Cairo.line_to ctx (float x2) (float y2) ;
    Cairo.Path.close ctx ;

    (* Apply the ink *)
    Cairo.stroke ctx ;
   ),
   (fun () ->
     let b = Buffer.create 10000 in
     (* Output a PNG in a string *)
     Cairo.PNG.write_to_stream surface (Buffer.add_string b);
     Buffer.contents b
   ))

let _ = Lwt_stream.iter draw_server (Eliom_bus.stream bus)

{% endhighlight %}

We also define a service that sends the picture:

{% highlight ocaml %}
let imageservice =
  Eliom_registration.String.register_service
    ~path:["image"]
    ~get_params:Eliom_parameter.unit
    (fun () () -> Lwt.return (image_string (), "image/png"))
{% endhighlight %}

### Eliom_registration

  The module `Eliom_registration` defines several modules with
  registration functions for a variety of data types. We have already
  seen `Eliom_registration.Html5` and `Eliom_registration.App`.
  The module `Eliom_registration.String` sends arbitrary byte output
  (represented by an OCaml string). The handler function must return
  a pair consisting of the content and the content-type.

  There are also several other output modules, for example:

- `Eliom_registration.File` to send static files
- `Eliom_registration.Redirection` to create a redirection towards another page
- `Eliom_registration.Any` to create services that decide late what
they want to send
- `Eliom_registration.Ocaml` to send any OCaml data to be used in a
client side program
- `Eliom_registration.Action` to create service with no output
(the handler function just performs a side effect on the server)
and reload the current page (or not). We will see an example of actions
in the next chapter.

### Loading the initial image

We now want to load the initial image once the canvas is created.  Add
the following lines just between the creation of the canvas context and the
creation of the slider:

{% highlight ocaml %}
(* The initial image: *)
let img =
  Eliom_content.Html5.To_dom.of_img
    (img ~alt:"canvas"
       ~src:(make_uri ~service:~%imageservice ())
       ())
in
img##.onload := Dom_html.handler
    (fun ev -> ctx##drawImage img 0. 0.; Js._false);
{% endhighlight %}

You are then ready to try your graffiti-application by
`make test.byte`.

Note, that the `Makefile` from the distillery automatically adds
the packages defined in `SERVER_PACKAGES` as an extension in your
configuration file `local/etc/graffiti/graffiti-test.conf`:

```
<extension findlib-package="cairo2" />
```


