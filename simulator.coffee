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
    @engines = null
    if v?
      @grid[k] = v
      @delta.changed[k] = v
    else
      delete @grid[k]
      @delta.changed[k] = null
  get: (x,y) -> @grid["#{x},#{y}"]

  getGrid: -> @grid

  findEngines: ->
    return if @engines
    @engines = []
    engineGrid = {}
    for k,v of @grid when v in ['positive', 'negative'] and !engineGrid[k]
      {x,y} = parseXY k
      e =
        grid: {}
        pressure: 0
        root: {x, y}

      size = 0
      fill {x,y}, (x, y) =>
        k = "#{x},#{y}"
        if @grid[k] is v
          size++

          engineGrid[k] = e
          e.grid[k] = true
          yes
        else
          no

      e.pressure = if v is 'positive' then size else -size
      @engines.push e
    return

  setGrid: (grid) ->
    @grid = grid || {}
    delete @grid.tw
    delete @grid.th
    @engines = null

    # Delta bankruptcy.
    @delta = {changed:{}, sound:{}}


  tryMove: (points, dx, dy) ->
    throw new Error('one at a time, fellas') if dx and dy
    return unless dx or dy
    isMe = (qx,qy) ->
      return true for {x,y} in points when x == qx and y == qy
      false
    if @held
      for {x,y} in points
        return false if @held.x is x and @held.y is y

    moved = no
    while dx || dy
      ddx = sign dx
      ddy = sign dy

      for {x,y} in points when not isMe(x+ddx,y+ddy)
        return moved if @get(x+ddx, y+ddy) isnt 'nothing'
          
      shuttle = {}
      for {x,y} in points
        shuttle["#{x},#{y}"] = @get x, y
        @set x, y, 'nothing'
      for p in points
        {x,y} = p
        @set x+ddx, y+ddy, shuttle["#{x},#{y}"]
        p.x += ddx
        p.y += ddy

      dx -= ddx
      dy -= ddy

      moved = yes

    moved

  getPressure: ->
    @findEngines()
    pressure = {}
    for e in @engines
      fill e.root, (x, y, hmm) =>
        k = "#{x},#{y}"

        cell = @grid[k]
        if e.grid[k] or cell in ['nothing', 'thinshuttle', 'thinsolid']
          pressure["#{x},#{y}"] = (pressure["#{x},#{y}"] ? 0) + e.pressure

          # Propogate pressure through bridges
          for [dx,dy] in cardinal_dirs
            _x = x + dx; _y = y + dy

            if @get(_x, _y) is 'bridge'
              while (c = @get _x, _y) is 'bridge'
                pressure["#{_x},#{_y}"] = (pressure["#{_x},#{_y}"] ? 0) + e.pressure
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

    @findEngines()
    for e in @engines
      fill e.root, (x, y, hmm) =>
        k = "#{x},#{y}"
        cell = @grid[k]

        if e.grid[k] or cell in ['nothing', 'thinshuttle', 'thinsolid']
            for [dx,dy] in cardinal_dirs
              _x = x + dx; _y = y + dy

              if (s = getShuttle _x, _y)
                s.force.x += dx * e.pressure
                s.force.y += dy * e.pressure

              else if @get(_x, _y) is 'bridge'
                _x += dx; _y += dy
                while (c = @get _x, _y) is 'bridge'
                  _x += dx; _y += dy
                
                # And now its not a bridge...
                if (s = getShuttle _x, _y)
                  s.force.x += dx * e.pressure
                  s.force.y += dy * e.pressure
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

  holdShuttle: ({x,y}) ->
    @held = {x,y}

  releaseShuttle: ->
    @held = null


  # ***** Drawing *****
  boundingBox: ->
    # calculate the bounding box
    top = left = bottom = right = null

    for k, v of @grid
      {x,y} = parseXY k
      left = x if left is null || x < left
      right = x+1 if right is null || x >= right
      top = y if top is null || y < top
      bottom = y+1 if bottom is null || y >= bottom

    {top, left, bottom, right}

  colors =
    bridge: '#2E96D6'
    negative: '#D65729'
    nothing: '#FFFFFF'
    positive: '#5CCC5C'
    shuttle: '#9328BD'
    solid: '#09191B'
    thinshuttle: '#D887F8'
    thinsolid: '#B5B5B5'
    buttonup: '#CC7B00'

  darkColors =
    bridge: '#487693'
    negative: '#814B37'
    nothing: '#7D7D7D'
    positive: '#4D8F4D'
    shuttle: '#604068'
    solid: '#706F76'
    thinshuttle: '#8E56A4'
    thinsolid: '#7D7D7D'
    buttonup: 'rgb(171,99,18)'

  drawCanvas: (ctx, size, worldToScreen) ->
    worldToScreen ||= (tx, ty) -> {px:tx * size, py:ty * size}

    # Draw the tiles
    pressure = @getPressure()
    for k,v of @grid
      {x:tx,y:ty} = parseXY k
      {px, py} = worldToScreen tx, ty

      ctx.fillStyle = colors[v]
      ctx.fillRect px, py, size, size

      if (p = pressure[k]) and p != 0
        ctx.fillStyle = if p < 0 then 'rgba(255,0,0,0.2)' else 'rgba(0,255,0,0.15)'
        ctx.fillRect px, py, size, size

# Exported for convenience.
Simulator.parseXY = parseXY


if typeof module != 'undefined'
  module.exports = Simulator
else
  this.Simulator = Simulator
