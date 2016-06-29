
minimist = require 'minimist'
{make_esc} = require 'iced-error'
iutils = require 'iced-utils'
{a_json_parse} = iutils.util

usage = () ->
  console.error """usage:
    json [-p] [-b] [-c] <path.to[4].your.obj>
"""

#==================================================

class Runner

  constructor : ({}) ->
    @pretty = false
    @b64decode = false
    @inspect = false
    @depth = 4
    @path = null
    @count = false

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
      @count = argv.c
      if argv._.length > 1
        err = new Error "only need one arg -- a path to your object -- which is optional"
      else if argv._.length is 1
        @path = argv._[0]
    cb err

  read_input : (opts, cb) ->
    bufs = []
    stream = process.stdin
    stream.resume()
    stream.on 'data', (buf) -> bufs.push buf
    stream.on 'end',  () ->
      cb null, Buffer.concat bufs

  pick_path : ({json}, cb) ->
    err = null
    if @path?
      parts = @path.split /\./
      for part, i in parts
        if not json?
          err = new Error "null value at #{parts[0...i].join(".")}"
        else
          json = json[part]
    cb err, json

  run : (opts, cb) ->
    esc = make_esc cb, "Runner::run"
    await @parse_argv opts, esc defer()
    await @read_input opts, esc defer buf
    await a_json_parse buf.toString(), esc defer json
    await @pick_path { json }, esc defer json
    cb null, json

#==================================================

r = new Runner
await r.run { argv : process.argv[2...] }, defer err, buf
if err?
  console.error err.toString()
else
  console.log buf
