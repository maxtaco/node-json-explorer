
minimist = require 'minimist'
{make_esc} = require 'iced-error'
iutils = require 'iced-utils'

usage = () ->
  console.error """usage:
    json [-p] [-b] <path.to[4].your.obj>
"""

#==================================================

class Runner

  constructor : ({}) ->
    @pretty = false
    @b64decode = false
    @inspect = false
    @depth = 4

  parse_argv : ({argv}, cb) ->
    argv = minimist argv
    if argv.h
      usage()
      err = new Error "usage: shown!"
    else
      @pretty = argv.p
      @b64decode = argv.b
      @inspect = argv.i
      @depth = argv.d
    cb err

  read_input : (opts, cb) ->
    bufs = []
    stream = process.stdin
    stream.resume()
    stream.on 'data', (buf) -> bufs.push buf
    stream.on 'end',  () ->
      cb null, Buffer.concat bufs

  run : (opts, cb) ->
    esc = make_esc cb, "Runner::run"
    await @parse_argv opts, esc defer()
    await @read_input opts, esc defer buf
    cb null, buf

#==================================================

r = new Runner
await r.run { argv : process.argv }, defer err, buf
if err?
  console.error err.toString()
else
  console.log buf
