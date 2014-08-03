# Test data making script. Use it like this:
#
# 1. Make some crazy monstrosity.
# 2. Copy it to the clipboard
# 3. pbpaste | coffee makedata.coffee > foo.json

isEmpty = (obj) ->
  for k of obj
    return false
  return true

input = ''
process.stdin.on 'data', (data) ->
  input += data.toString 'utf8'

process.stdin.on 'end', ->
  Simulator = require './simulator'

  grid = JSON.parse input
  delete grid.tw
  delete grid.th

  #console.log grid
  s = new Simulator grid

  # Simulate 100 steps, or until the simulator loops or stops changing.
  seenState = {}
  for [1..100]
    key = JSON.stringify s.getGrid()

    console.log key

    break if seenState[key]
    seenState[key] = true

    delta = s.step()
    break if isEmpty delta.changed

  return
