# This is the reference implementation for the boilerplate turing tarpit. This
# implementation is horrendously slow - it floodfills from every engine on
# every tick.
#
# The world is an infinite space stored in a javascript object as world["<x>,<y>"] = value.
#
# For example, world = {"10,20": "negative", "10,21": "shuttle"}
# Empty world values (null or undefined) are solid tiles. Coordinates can be
# negative (the space is infinite in all directions).
#
# Possible tile values are
#
# - positive: Positive pressure pump
# - negative: Negative pressure pump
# - nothing: Empty space
# - thinsolid: Solid rock which lets air pass (aka a grill / grate)
# - shuttle: Part of a shuttle - gets pushed by pressure
# - thinshuttle: Part of a shuttle which allows air to pass it
# - bridge: Equivalent to 'nothing' - allows pressure to pass horizontally and
#   vertially, without interference
# - null / undefined: Solid rock. No pressure / movement possible.
#
# This implementation welds shuttles which touch - I declare this to be (in
# general) undefined behaviour, because its inconvenient behaviour in a
# compiled implementation.

cardinal_dirs = [[0,1],[0,-1],[1,0],[-1,0]]
fill = (initial_square, f) ->
  visited = {}
  visited["#{initial_square.x},#{initial_square.y}"] = true
  to_explore = [initial_square]
  hmm = (x,y) ->
    k = "#{x},#{y}"
    if not visited[k]
      visited[k] = true
      to_explore.push {x,y}
  while n = to_explore.shift()
    ok = f n.x, n.y, hmm
    if ok
      hmm n.x+1, n.y
      hmm n.x-1, n.y
      hmm n.x, n.y+1
      hmm n.x, n.y-1
  return

parseXY = (k) ->
  [x,y] = k.split /,/
  {x:parseInt(x), y:parseInt(y)}

sign = (x) -> if x > 0 then 1 else if x < 0 then -1 else 0

class Simulator
  constructor: (grid) ->
    @setGrid grid

  set: (x, y, v) ->
    k = "#{x},#{y}"
    if v?
      @grid[k] = v
      @delta.changed[k] = v

      delete @engines[k]
      if v in ['positive', 'negative']
        @engines[k] = {x,y}
    else
      if @grid[k] in ['positive', 'negative']
        delete @engines[k]
      delete @grid[k]
      @delta.changed[k] = null
  get: (x,y) -> @grid["#{x},#{y}"]

  getGrid: -> @grid

  setGrid: (grid) ->
    @grid = grid || {}
    @engines = {}
    for k,v of @grid
      if v in ['positive', 'negative']
        {x,y} = parseXY k
        @engines[k] = {x,y}
    # Delta bankruptcy.
    @delta = {changed:{}, sound:{}}

  tryMove: (points, dx, dy) ->
    dx = if dx < 0 then -1 else if dx > 0 then 1 else 0
    dy = if dy < 0 then -1 else if dy > 0 then 1 else 0
    throw new Error('one at a time, fellas') if dx and dy
    return unless dx or dy
    isMe = (qx,qy) ->
      return true for {x,y} in points when x == qx and y == qy
      false
    for {x,y} in points when not isMe(x+dx,y+dy)
      if @get(x+dx, y+dy) isnt 'nothing'
        return false

    shuttle = {}
    for {x,y} in points
      shuttle["#{x},#{y}"] = @get x, y
      @set x, y, 'nothing'
    for {x,y} in points
      @set x+dx, y+dy, shuttle["#{x},#{y}"]

    true

  getPressure: ->
    pressure = {}
    for k,v of @engines
      direction = if 'positive' is @get v.x, v.y then 1 else -1
      fill v, (x, y, hmm) =>
        cell = @get x, y
        cell = 'nothing' if x is v.x and y is v.y
        if cell in ['nothing', 'thinshuttle', 'thinsolid']
          pressure["#{x},#{y}"] = (pressure["#{x},#{y}"] ? 0) + direction

          # Propogate pressure through bridges
          for [dx,dy] in cardinal_dirs
            _x = x + dx; _y = y + dy

            if @get(_x, _y) is 'bridge'
              while (c = @get _x, _y) is 'bridge'
                pressure["#{_x},#{_y}"] = (pressure["#{_x},#{_y}"] ? 0) + direction
                _x += dx; _y += dy
              
              if c in ['nothing', 'thinshuttle', 'thinsolid']
                hmm _x, _y

          return true
        false
    pressure
  step: ->
    shuttleMap = {}
    shuttles = []
    getShuttle = (x, y) =>
      return null unless @get(x, y) in ['shuttle']
      s = shuttleMap["#{x},#{y}"]
      return s if s

      shuttles.push (s = {points:[], force:{x:0,y:0}})

      # Flood fill the shuttle
      fill {x,y}, (x, y) =>
        if @get(x, y) in ['shuttle', 'thinshuttle']
          shuttleMap["#{x},#{y}"] = s
          s.points.push {x,y}
          true
        else
          false

      s

    # Populate the shuttles list with all shuttles. Needed because of gravity
    #for k,v of @grid
    #  {x,y} = parseXY k
    #  getShuttle x, y

    for k,v of @engines
      direction = if 'positive' is @get v.x, v.y then 1 else -1
      fill v, (x, y, hmm) =>
        cell = @get x, y
        cell = 'nothing' if x is v.x and y is v.y

        switch cell
          when 'nothing', 'thinshuttle', 'thinsolid'
            for [dx,dy] in cardinal_dirs
              _x = x + dx; _y = y + dy

              if (s = getShuttle _x, _y)
                s.force.x += dx * direction
                s.force.y += dy * direction

              else if @get(_x, _y) is 'bridge'
                _x += dx; _y += dy
                while (c = @get _x, _y) is 'bridge'
                  _x += dx; _y += dy
                
                # And now its not a bridge...
                if (s = getShuttle _x, _y)
                  s.force.x += dx * direction
                  s.force.y += dy * direction
                else if c in ['nothing', 'thinshuttle', 'thinsolid']
                  hmm _x, _y


            #pressure[[x,y]] = (pressure[[x,y]] ? 0) + direction

            true
          else
            false

    #console.log shuttles, @engines

    for {points, force} in shuttles
      movedY = @tryMove points, 0, force.y# + 1
      dy = if movedY then sign(force.y) else 0

      unless movedY
        movedX = @tryMove points, force.x, 0
        dx = if movedX then sign(force.x) else 0
      else
        dx = 0

      if dx or dy
        for {x,y} in points
          #console.log x+2*dx, y+2*dy, @get(x+2*dx, y+2*dy)
          if @get(x+2*dx, y+2*dy) in [undefined]
            @delta.sound["#{x},#{y}"] = true

    thisDelta = @delta
    @delta = {changed:{}, sound:{}}

    thisDelta

# Exported for convenience.
Simulator.parseXY = parseXY


if typeof module != 'undefined'
  module.exports = Simulator
else
  this.Simulator = Simulator
