
minimist = require 'minimist'
{make_esc} = require 'iced-error'
iutils = require 'iced-utils'
util = require 'util'
{a_json_parse} = iutils.util
{unpack} = require 'purepack'

usage = () ->
  console.error """usage:
json [-bcipu] [-s <spaces>] [-d <depth>] <path.to.4.your.obj>

  boolean flags:
    -b -- base64 decode the output (if it's a string)
    -c -- count the number of items in the array and output that
    -i -- use inspect rather than JSON.stringify
    -p -- pretty-print JSON.stringify
    -u -- base64 decode, msgpack unpack, and then reencode the object with buffers
          converted to base64

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
    @unpack = false

  parse_argv : ({argv}, cb) ->
    argv = minimist argv, { boolean : [ "p", "b", "i", "c", "u" ] }
    if argv.h
      usage()
      err = new Error "usage: shown!"
    else
      @pretty = true if argv.p
      @b64decode = true if argv.b
      @inspect = true if argv.i
      @depth = argv.d if argv.d?
      @count = true if argv.c
      @unpack = true if argv.u
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
      # need to call toString() in case it is a number, as returned by the command-line
      # parsing library we're using.
      parts = @path.toString().split /\./
      for part, i in parts
        if not json?
          err = new Error "null value at #{parts[0...i].join(".")}"
        else
          json = json[part]
    cb err, json

  b64encode_buffers : (o) ->
    if typeof o isnt 'object' then o
    else if not o? then o
    else if Buffer.isBuffer(o) then o.toString('base64')
    else if Array.isArray(o) then ( @b64encode_buffers(e) for e in o )
    else
      ret = {}
      for k,v of o
        ret[k] = @b64encode_buffers v
      ret

  json_format : (json) ->
    if @inspect then util.inspect json, { @depth }
    else if @pretty then JSON.stringify json, null, @spacing
    else JSON.stringify json

  output : ({json}, cb) ->
    ret = if typeof json is 'string'
      if @b64decode then (new Buffer json, "base64").toString('utf8')
      else json
    else if typeof json is 'object'
      if Array.isArray(json) and @count then json.length.toString('10')
      else @json_format json
    else if typeof json is 'number' then json.toString('10')
    cb null, ret

  parse_input : ({buf}, cb) ->
    esc = make_esc cb, "parse_input"
    err = ret = null
    s = buf.toString()
    if @unpack
      ret = err = null
      try ret = @b64encode_buffers unpack Buffer.from(s, "base64")
      catch e then err = e
    else
      await a_json_parse s, defer err, ret
    cb err, ret

  run : (opts, cb) ->
    esc = make_esc cb, "Runner::run"
    await @parse_argv opts, esc defer()
    await @read_input opts, esc defer buf
    await @parse_input { buf }, esc defer json
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
