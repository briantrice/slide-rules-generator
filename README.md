# slide-rules-generator

A generator for slide rules! As of right now, has a definition, transformation,
and rendering system for ticks.

There are four major folders in this project:

- `/ts` -- This is where the first attempt was written, it supported scale
  creation, but generally the API was crufty and most importantly rendering was
  very slow, so we rewrote it...
- `/wasm` -- This was a proof of concept using C & emscripten to generate ticks
  faster. Unfortunately, flexibility was lost due to C's lack of
  expressiveness.
- `/rust/sliderules` -- The first version that could be called a real proof of
  concept - generating specs and rendering them was very fast and the API was
  reasonably simple to type out. A live editor and a few examples together made
  for a nice experience!  However, poor separation of concerns /
  modularization, poor coding style, and some newly-found thorns in the API
  leads me to do a heavily inspried rewrite in...
- `/sliderules2` -- Not yet as fully featured as the first rust version, but
  all future development happens here.
