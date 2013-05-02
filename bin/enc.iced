#!/usr/bin/env iced

cmd = require '../lib/command'
log = require '../lib/log'
fs   = require 'fs'
myfs = require '../lib/fs'
crypto = require 'crypto'
mycrypto = require '../lib/crypto'
base58 = require '../lib/base58'

#=========================================================================

class Command extends cmd.Base
   
  #-----------------

  OPTS :
    o : 
      alias : "output"
      describe : "output file to write to"
    r :
      alias : "remove"
      describe : "remove the original file after encryption"
      boolean : true
    x :
      alias : "extension"
      describe : "encrypted file extension"

  USAGE : "Usage: $0 [opts] <infile>"

  #-----------------

  need_aws : -> false

  #-----------------

  check_args : () ->
    if @argv._.length isnt 1
      log.warn "Need an input file argument"
      false
    else true

  #-----------------
   
  constructor : () ->
    super()

  #-----------------

  file_extension : () -> @argv.x or @config.file_extension()

  #-----------------

  output_filename : () ->
    @argv.o or [ @infn, @file_extension() ].join ''

  #-----------------

  tmp_filename : (stem) ->
    ext = base58.encode crypto.rng 8

  #-----------------

  open_output : (cb) ->
    @outfn = @output_filename()
    @tmpfn = @tmp_filename @outfn
    ok = true
    await myfs.open { filename : @tmpfn, write : true }, defer err, ostream
    if err?
      log.error "Error opening temp outfile #{@tmpfn}: #{err}"
      ok = false
    cb ok, ostream

  #-----------------

  close_files : () ->
    await fs.rename @tmpfn, @outfn, defer err
    ok = true
    if err?
      log.error "Problem in file rename: #{err}"
      ok = false
    if ok and @argv.r
      await fs.unlink @infn, defer err
      if err?
        log.error "Error in removing original file #{@infn}: #{err}"
        ok = false
    cb ok

  #-----------------

  run : (cb) ->
    await @init @USAGE, @OPTS, defer ok
    console.log "A"
    ok = true
    if ok
      @infn = @argv._[0]
      await myfs.open { filename :  @infn }, defer err, istream, stat
      ok = false if err?
    console.log "B"
    if ok
      await @open_output defer ok, ostream
    console.log "C"
    if ok
      enc = new crypto.Encryptor { stat }
      await enc.setup_keys @pwmgr, defer ok
      if not ok
        log.error "Could not setup encryption keys"
    console.log "D"
    if ok
      istream.pipe(enc).pipe(ostream)
      await istream.once 'end', defer()
      await ostream.once 'finish', defer()
    console.log "E"
    if ok
      await @close_files defer()
    cb ok

#=========================================================================

cmd = new Command()
await cmd.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

