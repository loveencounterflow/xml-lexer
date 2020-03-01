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
type_noop               = 'noop'

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
  settings          = { { include_specials: false, }..., settings..., }
  lexer             = new EventEmitter()

  #---------------------------------------------------------------------------------------------------------
  # Registers
  #---------------------------------------------------------------------------------------------------------
  ρ =
    state:         state_data
    data:          ''
    tagname:       ''
    atrname:       ''
    atrvalue:      ''
    is_closing:     false
    prv_quote:      ''

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
      handler { $key, type, value, idx, ρ: registers, ref, }
    else
      lexer.emit 'data', { type, value, }

  lexer.stateMachine =

    #-------------------------------------------------------------------------------------------------------
    state_data:
      #.....................................................................................................
      action_lt: ( src, idx, chr ) =>
        if ρ.data.trim().length > 0
          emit '^1^', src, idx, type_text, ρ.data
        ρ.tagname    = ''
        ρ.is_closing  = false
        ρ.state       = state_tag_begin
      #.....................................................................................................
      action_chr: ( ( src, idx, chr ) => ρ.data += chr )

    #-------------------------------------------------------------------------------------------------------
    state_cdata:
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is ']]>' )
          emit '^2^', src, idx, type_text, ρ.data.slice 0, -3
          ρ.data  = ''
          ρ.state = state_data
        return null

    #-------------------------------------------------------------------------------------------------------
    state_tag_begin:
      #.....................................................................................................
      action_space: ( ( src, idx, chr ) => emit '^3^', src, idx, type_noop, chr )
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.tagname = chr
        ρ.state   = state_tagname
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        ρ.tagname   = ''
        ρ.is_closing = true

    #-------------------------------------------------------------------------------------------------------
    state_tagname:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        if ρ.is_closing
          ρ.state = state_tag_end
        else
          ρ.state = state_atrname_start
          emit '^4^', src, idx, type_open, ρ.tagname
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        if ρ.is_closing
          emit '^5^', src, idx, type_close, ρ.tagname
        else
          emit '^6^', src, idx, type_open, ρ.tagname
        ρ.data  = '';
        ρ.state = state_data;
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        ρ.state = state_tag_end
        emit '^7^', src, idx, type_open, ρ.tagname
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.tagname += chr
        if ρ.tagname is '![CDATA['
          ρ.state   = state_cdata
          ρ.data    = ''
          ρ.tagname = ''

    #-------------------------------------------------------------------------------------------------------
    state_tag_end:
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        emit '^8^', src, idx, type_close, ρ.tagname
        ρ.data  = ''
        ρ.state = state_data
      #.....................................................................................................
      action_chr: ( ( src, idx, chr ) => emit '^9^', src, idx, type_noop, chr )

    #-------------------------------------------------------------------------------------------------------
    state_atrname_start:
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.atrname  = chr
        ρ.state     = state_atrname
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        ρ.data = ''
        ρ.state = state_data
      #.....................................................................................................
      action_space: ( ( src, idx, chr ) => emit '^10^', src, idx, type_noop, chr )
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        ρ.is_closing = true
        ρ.state     = state_tag_end

    #-------------------------------------------------------------------------------------------------------
    state_atrname:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        ρ.state = state_atrname_end
      #.....................................................................................................
      action_equal: ( src, idx, chr ) =>
        emit '^11^', src, idx, type_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        ρ.atrvalue = ''
        emit '^12^', src, idx, type_atrname, ρ.atrname
        emit '^13^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.data      = ''
        ρ.state     = state_data
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        ρ.is_closing = true
        ρ.atrvalue = ''
        emit '^14^', src, idx, type_atrname, ρ.atrname
        emit '^15^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.state = state_tag_end
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.atrname += chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_end:
      #.....................................................................................................
      action_space: ( ( src, idx, chr ) => emit '^16^', src, idx, type_noop, chr )
      #.....................................................................................................
      action_equal: ( src, idx, chr ) =>
        emit '^17^', src, idx, type_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        ρ.atrvalue = ''
        emit '^18^', src, idx, type_atrname, ρ.atrname
        emit '^19^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.data      = ''
        ρ.state     = state_data
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.atrvalue = ''
        emit '^20^', src, idx, type_atrname, ρ.atrname
        emit '^21^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.atrname  = chr
        ρ.state     = state_atrname

    #-------------------------------------------------------------------------------------------------------
    state_atrvalue_begin:
      #.....................................................................................................
      action_space: ( ( src, idx, chr ) => emit '^22^', src, idx, type_noop, chr )
      #.....................................................................................................
      action_quote: ( src, idx, chr ) =>
        ρ.prv_quote  = chr
        ρ.atrvalue     = ''
        ρ.state         = state_atrvalue
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        ρ.atrvalue     = ''
        emit '^23^', src, idx, type_atrvalue, ρ.atrvalue
        ρ.data          = ''
        ρ.state         = state_data
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
        ρ.prv_quote  = ''
        ρ.atrvalue     = chr
        ρ.state         = state_atrvalue

    #-------------------------------------------------------------------------------------------------------
    state_atrvalue:
      #.....................................................................................................
      action_space: ( src, idx, chr ) =>
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^24^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
      #.....................................................................................................
      action_quote: ( src, idx, chr ) =>
        if chr is ρ.prv_quote
          emit '^25^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
        else
          ρ.atrvalue += chr
      #.....................................................................................................
      action_gt: ( src, idx, chr ) =>
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^26^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.data  = ''
          ρ.state = state_data
      #.....................................................................................................
      action_slash: ( src, idx, chr ) =>
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^27^', src, idx, type_atrvalue, ρ.atrvalue
          ρ.is_closing = true
          ρ.state     = state_tag_end
      #.....................................................................................................
      action_chr: ( src, idx, chr ) =>
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




