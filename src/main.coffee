'use strict'


EventEmitter = require('eventemitter3')
{ isa
  validate
  type_of }               = ( new ( require 'intertype' ).Intertype() ).export()

state_data              = 'state_data'
state_cdata             = 'state_cdata'
state_tag_begin         = 'state_tag_begin'
state_tagname           = 'state_tagname'
state_tag_end           = 'state_tag_end'
state_atrname_start     = 'state_atrname_start'
state_atrname           = 'state_atrname'
state_atrname_end       = 'state_atrname_end'
state_atrvalue_begin    = 'state_atrvalue_begin'
state_atrvalue          = 'state_atrvalue'
action_lt               = 'action_lt'
action_gt               = 'action_gt'
action_space            = 'action_space'
action_equal            = 'action_equal'
action_quote            = 'action_quote'
action_slash            = 'action_slash'
action_chr              = 'action_chr'
action_error            = 'action_error'
type_text               = 'text'
type_open               = 'open'
type_close              = 'close'
type_atrname            = 'atrname'
type_atrvalue           = 'atrvalue'
#...........................................................................................................
type_noop               = 'noop'
type_info               = 'info'
# type_sot                = 'sot' # Start Of Text

actions_by_chrs =
  ' ':                    action_space
  '\t':                   action_space
  '\n':                   action_space
  '\r':                   action_space
  '<':                    action_lt
  '>':                    action_gt
  '"':                    action_quote
  "'":                    action_quote
  '=':                    action_equal
  '/':                    action_slash

#-----------------------------------------------------------------------------------------------------------
create = ( settings, handler ) ->
  switch arity = arguments.length
    when 0 then null
    when 1 then [ settings, handler, ] = [ null, settings, ]
    when 2 then null
    else throw new Error "^55563^ expected 1 or 2 arguments, got #{arity}"
  [ settings, handler, ] = [ handler, null, ] unless isa.function handler
  ### TAINT validate.xmllexer_settings settings ? {} ###
  ### TAINT validate.function handler ###
  defaults          =
    include_specials:   false
    emit_info:          false
    emit_noop:          false
  settings          = { defaults..., settings..., }
  lexer             = new EventEmitter()

  #---------------------------------------------------------------------------------------------------------
  # Registers
  #---------------------------------------------------------------------------------------------------------
  ρ =
    state:          state_data
    data:           ''
    tagname:        ''
    atrname:        ''
    atrvalue:       ''
    is_closing:     false
    prv_quote:      ''
    txtl:           null # first index of current or most recent text ('data' or 'cdata') stretch
    tagl:           null # first index of current or most recent tag
    tagr:           null # last index of current or most recent tag

  #---------------------------------------------------------------------------------------------------------
  step = ( src, idx, chr ) =>
    if settings.debug then console.log ρ.state, chr
    actions = lexer.stateMachine[ ρ.state ]
    action  = actions[ actions_by_chrs[ chr ] ? action_chr ] ? actions[ action_error ] ? actions[ action_chr ]
    action src, idx, chr
    return null

  #---------------------------------------------------------------------------------------------------------
  lexer.write = ( src ) =>
    for idx in [ 0 ... src.length ]
      step src, idx, src[ idx ]
    return null

  #---------------------------------------------------------------------------------------------------------
  lexer.flush = =>

  #---------------------------------------------------------------------------------------------------------
  emit = ( ref, src, idx, type, value ) =>
    # sigil = null
    # # tags like: '?xml', '!DOCTYPE', comments
    return null if ( type is type_noop ) and ( not settings.emit_noop )
    return null if ( type is type_info ) and ( not settings.emit_info )
    unless settings.include_specials
      return null if ρ.tagname[ 0 ] in '!?'
      return null if type is type_noop
    # switch sigil = ρ.tagname[ 0 ]
    #   when '?' then type = ''
    #   when '!' then type = 'declaration'
    # event.sigil = sigil if sigil?
    event = { ref, type, value }
    registers = {}
    for k, v of ρ
      registers[ k ] = v unless v in [ undefined, '', false, ]
    if handler?
      $key = "^xmlxr:#{type}"
      handler { $key, type, value, idx, txtl: ρ.txtl, tagl: ρ.tagl, tagr: ρ.tagr, ρ: registers, ref, }
    else
      lexer.emit 'data', { type, value, }

  lexer.stateMachine =

    #-------------------------------------------------------------------------------------------------------
    state_data:
      #.....................................................................................................
      action_lt: ( src, idx, chr ) =>
        emit '^d1+^', src, idx, type_info, chr
        if ρ.data.trim().length > 0
          emit '^d2^', src, idx, type_text, ρ.data
        ρ.tagl        = idx
        ρ.tagname     = ''
        ρ.is_closing  = false
        ρ.state       = state_tag_begin
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d3+^', src, idx, type_info, chr
        if ρ.data is ''
          ρ.txtl = idx
        ρ.data += chr

    #-------------------------------------------------------------------------------------------------------
    state_cdata:
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d4+^', src, idx, type_info, chr
        if ρ.data is ''
          ρ.txtl = idx
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is ']]>' )
          emit '^d5^', src, idx, type_text, ρ.data.slice 0, -3
          ρ.data  = ''
          ρ.state = state_data
        return null

    #-------------------------------------------------------------------------------------------------------
    state_tag_begin:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d6+^', src, idx, type_info, chr
        emit '^d7^', src, idx, type_noop, chr
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d8+^', src, idx, type_info, chr
        ρ.tagname = chr
        ρ.state   = state_tagname
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        emit '^d9+^', src, idx, type_info, chr
        ρ.tagname   = ''
        ρ.is_closing = true

    #-------------------------------------------------------------------------------------------------------
    state_tagname:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d10+^', src, idx, type_info, chr
        if ρ.is_closing
          ρ.state = state_tag_end
        else
          ρ.state = state_atrname_start
          emit '^d11^', src, idx, type_open, ρ.tagname
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d12+^', src, idx, type_info, chr
        if ρ.is_closing
          ρ.tagr = idx + 1
          emit '^d13^', src, idx, type_close, ρ.tagname
        else
          emit '^d14^', src, idx, type_open, ρ.tagname
        ρ.data  = '';
        ρ.state = state_data;
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        emit '^d15+^', src, idx, type_info, chr
        ρ.state = state_tag_end
        emit '^d16^', src, idx, type_open, ρ.tagname
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d17+^', src, idx, type_info, chr
        ρ.tagname += chr
        if ρ.tagname is '![CDATA['
          ρ.state   = state_cdata
          ρ.data    = ''
          ρ.tagname = ''

    #-------------------------------------------------------------------------------------------------------
    state_tag_end:
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d18+^', src, idx, type_info, chr
        emit '^d19^', src, idx, type_close, ρ.tagname
        ρ.data  = ''
        ρ.state = state_data
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d20+^', src, idx, type_info, chr
        emit '^d21^', src, idx, type_noop, chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_start:
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d22+^', src, idx, type_info, chr
        ρ.atrname  = chr
        ρ.state     = state_atrname
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d23+^', src, idx, type_info, chr
        ρ.data = ''
        ρ.state = state_data
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d24+^', src, idx, type_info, chr
        emit '^d25^', src, idx, type_noop, chr
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        emit '^d26+^', src, idx, type_info, chr
        ρ.is_closing = true
        ρ.state     = state_tag_end

    #-------------------------------------------------------------------------------------------------------
    state_atrname:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d27+^', src, idx, type_info, chr
        ρ.state = state_atrname_end
      #.....................................................................................................
      action_equal: ( src, idx, chr ) =>
        emit '^d28+^', src, idx, type_info, chr
        emit '^d29^', src, idx, type_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d30+^', src, idx, type_info, chr
        ρ.atrvalue = ''
        emit '^d31^', src, idx, type_atrname, ρ.atrname
        emit '^d32^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.data      = ''
        ρ.state     = state_data
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        emit '^d33+^', src, idx, type_info, chr
        ρ.is_closing = true
        ρ.atrvalue = ''
        emit '^d34^', src, idx, type_atrname, ρ.atrname
        emit '^d35^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.state = state_tag_end
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d36+^', src, idx, type_info, chr
        ρ.atrname += chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_end:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d37+^', src, idx, type_info, chr
        emit '^d38^', src, idx, type_noop, chr
      #.....................................................................................................
      action_equal: ( src, idx, chr ) =>
        emit '^d39+^', src, idx, type_info, chr
        emit '^d40^', src, idx, type_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d41+^', src, idx, type_info, chr
        ρ.atrvalue = ''
        emit '^d42^', src, idx, type_atrname, ρ.atrname
        emit '^d43^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.data      = ''
        ρ.state     = state_data
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d44+^', src, idx, type_info, chr
        ρ.atrvalue = ''
        emit '^d45^', src, idx, type_atrname, ρ.atrname
        emit '^d46^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.atrname  = chr
        ρ.state     = state_atrname

    #-------------------------------------------------------------------------------------------------------
    state_atrvalue_begin:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d47+^', src, idx, type_info, chr
        emit '^d48^', src, idx, type_noop, chr
      #.....................................................................................................
      action_quote: ( src, idx, chr ) =>
        emit '^d49+^', src, idx, type_info, chr
        ρ.prv_quote  = chr
        ρ.atrvalue     = ''
        ρ.state         = state_atrvalue
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d50+^', src, idx, type_info, chr
        ρ.atrvalue     = ''
        emit '^d51^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.data          = ''
        ρ.state         = state_data
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d52+^', src, idx, type_info, chr
        ρ.prv_quote     = ''
        ρ.atrvalue      = chr
        ρ.state         = state_atrvalue

    #-------------------------------------------------------------------------------------------------------
    state_atrvalue:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        emit '^d53+^', src, idx, type_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d54^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
      #.....................................................................................................
      action_quote: ( src, idx, chr ) =>
        emit '^d55+^', src, idx, type_info, chr
        if chr is ρ.prv_quote
          emit '^d56^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
        else
          ρ.atrvalue += chr
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^d57+^', src, idx, type_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d58^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.data  = ''
          ρ.state = state_data
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        emit '^d59+^', src, idx, type_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d60^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.is_closing = true
          ρ.state     = state_tag_end
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        emit '^d61+^', src, idx, type_info, chr
        ρ.atrvalue += chr

  #---------------------------------------------------------------------------------------------------------
  return lexer


module.exports = {
  state_data
  state_cdata
  state_tag_begin
  state_tagname
  state_tag_end
  state_atrname_start
  state_atrname
  state_atrname_end
  state_atrvalue_begin
  state_atrvalue
  action_lt
  action_gt
  action_space
  action_equal
  action_quote
  action_slash
  action_chr
  action_error
  type_text
  type_open
  type_close
  type_atrname
  type_atrvalue
  type_noop
  create }




