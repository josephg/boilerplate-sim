fs = require 'fs'
Simulator = require './simulator'
assert = require 'assert'

describe 'simulator', ->

  describe 'from test data', ->
    files = fs.readdirSync "#{__dirname}/testdata"

    for filename in files when filename.match /\.json$/
      do (filename) -> it filename, ->
        lines = fs.readFileSync("#{__dirname}/testdata/#{filename}", 'utf8').split '\n'

        initial = JSON.parse lines.shift()
        s = new Simulator initial

        for l in lines when l
          expected = JSON.parse l

          s.step()
          assert.deepEqual expected, s.getGrid()
