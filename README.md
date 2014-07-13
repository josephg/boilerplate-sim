# BOILERPLATE

This is a reference simulator for a steam / air pressure based turing tarpit.
The world is a 2d space deep underground. You can empty out space, which can be
pressurized with pumps. Pressurized air pushes (or pulls) shuttles, which can
be used as switches.

This repository contains a reference implementation for a simulator. I've
pulled it out of the [main boilerplate
repo](https://github.com/josephg/boilerplate) because I want to use it in
several places, and I want to make an optimized compiler. This code is very
poorly optimized - it floodfills from all engines every tick. But computers are
very fast these days, so its totally fine for most uses.

In the simulator, the world is an infinite 2d grid. Each cell in the grid contains
one of the following values:

- **positive**: Positive pressure pump
- **negative**: Negative pressure pump
- **nothing**: Empty space
- **thinsolid**: A grill / grate. Shuttles cannot pass but air can.
- **shuttle**: Part of a shuttle - gets pushed by pressure
- **thinshuttle**: Part of a shuttle, but allows air to pass
- **bridge**: Equivalent to 'nothing' - allows pressure to pass horizontally
  and vertially, without interference
- **null / undefined**: Solid rock. No pressure / movement possible.



## Using it

A quick example:

```
// only needed in nodejs
var Simulator = require('boilerplate-sim');

var sim = new Simulator(); // Can be initialized with a JSON grid object
sim.set(10, 10, 'negative');
sim.set(10, 11, 'nothing');
sim.set(10, 12, 'nothing');
sim.set(10, 13, 'shuttle');

sim.step(); // Returns a delta of what changed this tick - in this case 

console.log(sim.get(10, 12)); // 'shuttle'
console.log(sim.get(10, 13)); // 'nothing'

sim.getPressure(); // Returns an object describing the pressure in all cells

console.log(sim.getGrid()); // Returns a JSON object with the world state
```

---

From node:

```
% npm install boilerplate-sim
```

... Or include the `simulator.js` file in your web app.


### Your very own Simulator

The module exposes the `Simulator` class. Make a new simulator:

```javascript
var sim = new Simulator(); // Create a new, empty world

// or:

var grid = {
  '10,10': 'negative',
  '10,11': 'nothing',
  '10,12': 'shuttle'
};
var sim = new Simulator(grid);
```

The grid object contains a description of the entire world. It is pure JSON
(for easy serialization). It can be pulled back out of the simulator using
`sim.getGrid()`. Don't modify this object directly - instead use
`sim.set(x, y, value)` (described below).

### Stepping the world

The simulator has a `step()` function which advances the world by one tick.
Step returns an object with a `changed` property:

```javascript
var grid = {
  '10,10': 'negative',
  '10,11': 'nothing',
  '10,12': 'shuttle'
};
var sim = new Simulator(grid);

console.log(sim.step().changed);
// Prints { '10,12': 'nothing', '10,11': 'shuttle' }
```

The changed property returns an object containing all world values which have
changed since the last time step was called. This includes values you set
manually using `set`.

### Getting and setting values

To modify world values, call `sim.set(x, y, value)`. *x* and *y* are integer
coordinates. They can be negative. *value* should be one of:

The value should either be a string or null. If its a string, it should be one
of *positive*, *negative*, *nothing*, *thinsolid*, *shuttle*, *thinshuttle* or
*bridge*. null means solid rock. If you specify a string which is not in the
list, behaviour is undefined.

You can get the current value of any cell using `sim.get(x, y)`. It returns the
same values you would pass to `set`. (It may return undefined instead of null
to indicate solid rock).

You can get the entire world state using `sim.getGrid()`. This returns a JSON
object containing the entire world state. The reference simulator uses a JSON
object to store the world state internally, and returns that object directly.
So, this method is very cheap to call, but the grid object isn't guaranteed to
still be useful after you call step(). Also don't modify the object returned
from getGrid() yourself.

### Pressure

Its sometimes useful to know the pressure of all cells (eg, in rendering). You
can use the `sim.getPressure()` method. This returns an object which maps grid
coordinates to pressure integers. This is quite expensive to calculate - about
as expensive as calling `step()`.

This is a convenience function - if you're trying to make a compatible
implementation of the simulator, you don't have to implement getPressure().



---

# License

> Standard ISC License

Copyright (c) 2011-2014, Joseph Gentle, Jeremy Apthorp

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

