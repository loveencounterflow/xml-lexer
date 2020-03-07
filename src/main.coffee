'use strict'


'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'XML-LEXER'
log                       = CND.get_logger 'plain',     badge
info                      = CND.get_logger 'info',      badge
whisper                   = CND.get_logger 'whisper',   badge
alert                     = CND.get_logger 'alert',     badge
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
echo                      = CND.echo.bind CND
#...........................................................................................................
{ assign
  jr }                    = CND
#...........................................................................................................
DATOM                     = new ( require 'datom' ).Datom { dirty: false, }
{ new_datom
  wrap_datom
  lets
  freeze
  select }                = DATOM.export()


EventEmitter = require('eventemitter3')
{ isa
  validate
  type_of }               = ( new ( require 'intertype' ).Intertype() ).export()

state_data              = 'state_data'
state_cdata             = 'state_cdata'
state_comment           = 'state_comment'
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
name_text               = 'text'
name_open               = 'open'
name_openfinish         = 'openfinish'
name_opencdata          = 'opencdata'
name_close              = 'close'
name_closecdata         = 'closecdata'
name_comment            = 'comment'
name_atrname            = 'atrname'
name_atrvalue           = 'atrvalue'
name_extraneous         = 'extraneous'
name_solitary           = 'solitary'
name_missingbracket     = 'missingbracket'
#...........................................................................................................
name_noop               = 'noop'
name_info               = 'info'
# name_sot                = 'sot' # Start Of Text

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
    has_slash:      false
    txtl:           null # first index of current or most recent text ('data' or 'cdata') stretch
    tagl:           null # first index of current or most recent tag
    tagr:           null # last index of current or most recent tag
    atrl:           null # first index of either atrname or atrvalue
    decl_syntax:    false # true if tag opened with `<?`
    src:            null
    max_idx:        null


  #---------------------------------------------------------------------------------------------------------
  step = ( idx, chr ) =>
    if settings.debug then console.log ρ.state, chr
    actions = lexer.stateMachine[ ρ.state ]
    action  = actions[ actions_by_chrs[ chr ] ? action_chr ] ? actions[ action_error ] ? actions[ action_chr ]
    action idx, chr
    return null

  #---------------------------------------------------------------------------------------------------------
  lexer.write = ( src ) =>
    ρ.max_idx = 0
    ρ.src     = src
    for idx in [ 0 ... src.length ]
      step idx, src[ idx ]
    return null

  #---------------------------------------------------------------------------------------------------------
  lexer.flush = =>
    debug '^4445^', ρ.max_idx, ρ.src.length
    debug '^4445^', ρ.max_idx < ρ.src.length - 1
    ρ.src

  #---------------------------------------------------------------------------------------------------------
  emit = ( ref, idx, name, text ) =>
    # sigil = null
    # # tags like: '?xml', '!DOCTYPE', comments
    ρ.max_idx = idx unless name in [ name_noop, name_info, ]
    return null if ( name is name_noop ) and ( not settings.emit_noop )
    return null if ( name is name_info ) and ( not settings.emit_info )
    unless settings.include_specials
      return null if ρ.tagname[ 0 ] in '!?'
      return null if name is name_noop
    if handler?
      { txtl, tagl, tagr, atrl, has_slash, } = ρ
      stop                        = idx
      handler new_datom '^raw', { name, text, stop, txtl, tagl, tagr, atrl, has_slash, $: ref, }
    else
      return null if name is 'openfinish'
      # return null if name is 'extraneous'
      # return null if name is 'missingbracket'
      type  = name
      value = text
      lexer.emit 'data', { type, value, }
    return null

  lexer.stateMachine =

    #-------------------------------------------------------------------------------------------------------
    state_data:
      #.....................................................................................................
      action_lt: ( idx, chr ) =>
        emit '^d1^', idx, name_info, chr
        if ρ.data.length > 0
          emit '^d2^', idx, name_text, ρ.data
        ρ.tagl        = idx
        ρ.tagname     = ''
        ρ.is_closing  = false
        ρ.state       = state_tag_begin
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d3^', idx, name_info, chr
        if ρ.data is ''
          ρ.txtl = idx
        ρ.data += chr

    #-------------------------------------------------------------------------------------------------------
    state_cdata:
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d4^', idx, name_info, chr
        if ρ.data is ''
          ρ.txtl = idx
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is ']]>' )
          ρ.tagl = idx - 2
          emit '^d5^', idx, name_text,       ρ.data.slice 0, -3
          emit '^d6^', idx, name_closecdata, ρ.data.slice -3
          ρ.data  = ''
          ρ.state = state_data
        return null

    #-------------------------------------------------------------------------------------------------------
    state_comment:
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d7^', idx, name_info, chr
        if ρ.data is ''
          ρ.txtl = idx - 4
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is '-->' )
          ρ.tagl = idx - 2
          emit '^d8^', idx, name_comment, '<!--' + ρ.data
          ρ.data  = ''
          ρ.state = state_data
        return null

    #-------------------------------------------------------------------------------------------------------
    state_tag_begin:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d10^', idx, name_info, chr
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d11^', idx, name_info, chr
        ρ.decl_syntax = ( chr is '?' )
        ρ.tagname     = chr
        ρ.state       = state_tagname
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d12^', idx, name_info, chr
        ρ.tagname   = ''
        ρ.is_closing = true

    #-------------------------------------------------------------------------------------------------------
    state_tagname:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d13^', idx, name_info, chr
        if ρ.is_closing
          ρ.state = state_tag_end
        else
          ρ.state = state_atrname_start
          emit '^d14^', idx, name_open, ρ.tagname
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d15^', idx, name_info, chr
        if ρ.is_closing
          ρ.tagr = idx + 1
          emit '^d16^', idx, name_close, ρ.tagname
        else
          emit '^d17^', idx, name_open, ρ.tagname
          emit '^d18^', idx, name_openfinish, ρ.tagname
        ρ.data  = '';
        ρ.state = state_data;
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d19^', idx, name_info, chr
        ρ.has_slash = true
        ρ.state     = state_tag_end
        emit '^d20^', idx, name_open, ρ.tagname
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d21^', idx, name_info, chr
        ρ.tagname += chr
        if ρ.tagname is '![CDATA['
          emit '^d22^', idx, name_opencdata, ρ.tagname
          ρ.state   = state_cdata
          ρ.data    = ''
          ρ.tagname = ''
        else if ρ.tagname is '!--'
          ρ.state   = state_comment
          ρ.data    = ''
          ρ.tagname = ''
        return null

    #-------------------------------------------------------------------------------------------------------
    state_tag_end:
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d23^', idx, name_info, chr
        if ρ.has_slash
          ρ.has_slash = false
          emit '^d24^', idx, name_solitary, ρ.tagname
        else
          emit '^d25^', idx, name_close, ρ.tagname
        ρ.data  = ''
        ρ.state = state_data
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d26^', idx, name_info, chr
        emit '^d27^', idx, name_extraneous, chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_start:
      #.....................................................................................................
      action_lt: ( idx, chr ) =>
        emit '^d28^', idx, name_info, chr
        emit '^d29^', idx, name_missingbracket, chr
        # emit '^d30^',  idx, name_openfinish, chr
        ρ.state     = state_tag_begin
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d31^', idx, name_info, chr
        ρ.atrl      = idx
        ρ.atrname   = chr
        ρ.state     = state_atrname
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d32^', idx, name_info, chr
        emit '^d33^',  idx, name_openfinish, chr
        ρ.data = ''
        ρ.state = state_data
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d34^', idx, name_info, chr
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d35^', idx, name_info, chr
        ρ.has_slash   = true
        ρ.is_closing  = true
        ρ.state       = state_tag_end

    #-------------------------------------------------------------------------------------------------------
    state_atrname:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d36^', idx, name_info, chr
        ρ.state = state_atrname_end
      #.....................................................................................................
      action_equal: ( idx, chr ) =>
        emit '^d37^', idx, name_info, chr
        emit '^d38^', idx, name_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d39^', idx, name_info, chr
        ρ.atrvalue = ''
        unless ρ.decl_syntax and ρ.atrname is '?'
          emit '^d40^', idx, name_atrname, ρ.atrname
          emit '^d41^', idx, name_atrvalue, ρ.atrvalue
        emit '^d42^', idx, name_openfinish, ρ.tagname
        ρ.data      = ''
        ρ.state     = state_data
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d43^', idx, name_info, chr
        ρ.has_slash   = true
        ρ.is_closing  = true
        ρ.atrvalue    = ''
        emit '^d44^', idx, name_atrname, ρ.atrname
        emit '^d45^', idx, name_atrvalue, ρ.atrvalue
        ρ.state = state_tag_end
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d46^', idx, name_info, chr
        ρ.atrname += chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_end:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d47^', idx, name_info, chr
        emit '^d48^', idx, name_noop, chr
      #.....................................................................................................
      action_equal: ( idx, chr ) =>
        emit '^d49^', idx, name_info, chr
        emit '^d50^', idx, name_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d51^', idx, name_info, chr
        ρ.atrvalue  = ''
        ρ.data      = ''
        emit '^d52^', idx, name_atrname, ρ.atrname
        emit '^d53^', idx, name_atrvalue, ρ.atrvalue
        emit '^d54^', idx, name_openfinish, ρ.tagname
        ρ.state     = state_data
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d55^', idx, name_info, chr
        ρ.atrvalue = ''
        emit '^d56^', idx, name_atrname, ρ.atrname
        emit '^d57^', idx, name_atrvalue, ρ.atrvalue
        ρ.atrname  = chr
        ρ.state     = state_atrname
    #-------------------------------------------------------------------------------------------------------
    state_atrvalue_begin:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d58^', idx, name_info, chr
      #.....................................................................................................
      action_quote: ( idx, chr ) =>
        emit '^d59^', idx, name_info, chr
        ρ.prv_quote  = chr
        ρ.atrvalue     = ''
        ρ.state         = state_atrvalue
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d60^', idx, name_info, chr
        ρ.atrvalue     = ''
        emit '^d61^', idx, name_atrvalue, ρ.atrvalue
        ρ.data          = ''
        ρ.state         = state_data
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d62^', idx, name_info, chr
        ρ.prv_quote     = ''
        ρ.atrvalue      = chr
        ρ.state         = state_atrvalue

    #-------------------------------------------------------------------------------------------------------
    state_atrvalue:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d63^', idx, name_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d64^', idx, name_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
      #.....................................................................................................
      action_quote: ( idx, chr ) =>
        emit '^d65^', idx, name_info, chr
        if chr is ρ.prv_quote
          emit '^d66^', idx, name_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
        else
          ρ.atrvalue += chr
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        if ρ.prv_quote.length > 0
          emit '^d67^', idx, name_info, chr
          ρ.atrvalue += chr
        else
          emit '^d68^', idx, name_info, chr
          emit '^d69^', idx, name_atrvalue, ρ.atrvalue
          emit '^d70^', idx, name_openfinish, chr
          ρ.data  = ''
          ρ.state = state_data
        return null
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d71^', idx, name_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d72^', idx, name_atrvalue, ρ.atrvalue
          ρ.has_slash   = true
          ρ.is_closing  = true
          ρ.state       = state_tag_end
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d73^', idx, name_info, chr
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
  name_text
  name_open
  name_close
  name_atrname
  name_atrvalue
  name_noop
  name_solitary
  name_extraneous
  name_missingbracket
  create }




