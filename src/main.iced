
minimist = require 'minimist'
{make_esc} = require 'iced-error'
iutils = require 'iced-utils'
util = require 'util'
{a_json_parse} = iutils.util

usage = () ->
  console.error """usage:
json [-bcip] [-s <spaces>] [-d <depth>] <path.to.4.your.obj>

  boolean flags:
    -b -- base64 decode the output (if it's a string)
    -c -- count the number of items in the array and output that
    -i -- use inspect rather than JSON.stringify
    -p -- pretty-print JSON.stringify

  integer flags:
    -s <space> -- Use the given number of spaces in pretty-print (2 by default)
    -d <depth> -- only investigate depth levels in inspect (infinity by default)
"""

#==================================================

class Runner

  constructor : ({}) ->
    @pretty = false
    @b64decode = false
    @inspect = false
    @depth = null
    @spacing = 2
    @path = null
    @count = false

  parse_argv : ({argv}, cb) ->
    argv = minimist argv, { boolean : [ "p", "b", "i", "c" ] }
    if argv.h
      usage()
      err = new Error "usage: shown!"
    else
      @pretty = true if argv.p
      @b64decode = true if argv.b
      @inspect = true if argv.i
      @depth = argv.d if argv.d?
      @count = true if argv.c
      @spacing = argv.s if argv.s?
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

  output : ({json}, cb) ->
    ret = if typeof json is 'string'
      if @b64decode then (new Buffer json, "base64").toString('utf8')
      else json
    else if typeof json is 'object'
      if Array.isArray(json) and @count then json.length.toString('10')
      else if @inspect then util.inspect json, { @depth }
      else if @pretty then JSON.stringify json, null, @spacing
      else JSON.stringify json
    else if typeof json is 'number' then json.toString('10')
    cb null, ret

  run : (opts, cb) ->
    esc = make_esc cb, "Runner::run"
    await @parse_argv opts, esc defer()
    await @read_input opts, esc defer buf
    await a_json_parse buf.toString(), esc defer json
    await @pick_path { json }, esc defer json
    await @output { json }, esc defer out
    cb null, out

#==================================================

exports.run = (cb) ->
  r = new Runner
  await r.run { argv : process.argv[2...] }, defer err, buf
  rc = 0
  if err?
    rc = 2
    console.error err.toString()
  else
    await process.stdout.write buf, defer()
  cb rc
