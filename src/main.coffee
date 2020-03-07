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
name_unfinishedtag      = 'unfinishedtag'
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
  lexer             = {}

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
    # debug '^4445^', ρ.max_idx, ρ.src.length
    # debug '^4445^', ρ.state
    # debug '^4445^', ρ
    return null unless ρ.max_idx < ρ.src.length - 1
    idx = ρ.src.length - 1
    switch ρ.state
      when state_atrvalue_begin, state_atrvalue
        emit '^d100^', idx, name_atrvalue,        ρ.atrvalue
        emit '^d101^', idx, name_openfinish,      ρ.tagname   ? ''
        emit '^d102^', idx, name_unfinishedtag,   ''
      when state_atrname
        emit '^d103^', idx, name_atrname,         ρ.atrname   ? ''
        emit '^d104^', idx, name_atrvalue,        ρ.atrvalue  ? ''
        emit '^d105^', idx, name_openfinish,      ρ.tagname   ? ''
        emit '^d106^', idx, name_unfinishedtag,   ''
      when state_atrname_start, state_tagname
        emit '^d107^', idx, name_open,           ρ.tagname   ? ''
        emit '^d108^', idx, name_openfinish,      ρ.tagname   ? ''
        emit '^d109^', idx, name_unfinishedtag,   ''
      when state_tag_begin
        emit '^d110^', idx, name_open,           ''
        emit '^d111^', idx, name_openfinish,     ''
        emit '^d112^', idx, name_unfinishedtag,  ''
      when state_data
        emit '^d113^', idx, name_text,           ρ.data      ? ''
        emit '^d114^', idx, name_extraneous,     '' if ρ.data.endsWith '>'
      when state_cdata
        emit '^d115^', idx, name_text,           ρ.data      ? ''
        emit '^d116^', idx, name_unfinishedtag,  ''
      when state_comment
        emit '^d117^', idx, name_text,           '<!--' + ( ρ.data ? '' )
        emit '^d118^', idx, name_unfinishedtag,  ''
      else throw new Error "^4455^ unable to deal with pending state #{ρ.state}"
    return null

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
    { txtl, tagl, tagr, atrl, has_slash, } = ρ
    stop                        = idx
    handler new_datom '^raw', { name, text, stop, txtl, tagl, tagr, atrl, has_slash, $: ref, }
    return null

  lexer.stateMachine =

    #-------------------------------------------------------------------------------------------------------
    state_data:
      #.....................................................................................................
      action_lt: ( idx, chr ) =>
        emit '^d119^', idx, name_info, chr
        if ρ.data.length > 0
          emit '^d120^', idx, name_text, ρ.data
        ρ.tagl        = idx
        ρ.tagname     = ''
        ρ.is_closing  = false
        ρ.state       = state_tag_begin
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d121^', idx, name_info, chr
        if ρ.data is ''
          ρ.txtl = idx
        ρ.data += chr

    #-------------------------------------------------------------------------------------------------------
    state_cdata:
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d122^', idx, name_info, chr
        if ρ.data is ''
          ρ.txtl = idx
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is ']]>' )
          ρ.tagl = idx - 2
          emit '^d123^', idx, name_text,       ρ.data.slice 0, -3
          emit '^d124^', idx, name_closecdata, ρ.data.slice -3
          ρ.data  = ''
          ρ.state = state_data
        return null

    #-------------------------------------------------------------------------------------------------------
    state_comment:
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d125^', idx, name_info, chr
        if ρ.data is ''
          ρ.txtl = idx - 4
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is '-->' )
          ρ.tagl = idx - 2
          emit '^d126^', idx, name_comment, '<!--' + ρ.data
          ρ.data  = ''
          ρ.state = state_data
        return null

    #-------------------------------------------------------------------------------------------------------
    state_tag_begin:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d127^', idx, name_info, chr
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d128^', idx, name_info, chr
        ρ.decl_syntax = ( chr is '?' )
        ρ.tagname     = chr
        ρ.state       = state_tagname
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d129^', idx, name_info, chr
        ρ.tagname   = ''
        ρ.is_closing = true

    #-------------------------------------------------------------------------------------------------------
    state_tagname:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d130^', idx, name_info, chr
        if ρ.is_closing
          ρ.state = state_tag_end
        else
          ρ.state = state_atrname_start
          emit '^d131^', idx, name_open, ρ.tagname
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d132^', idx, name_info, chr
        if ρ.is_closing
          ρ.tagr = idx + 1
          emit '^d133^', idx, name_close, ρ.tagname
        else
          emit '^d134^', idx, name_open, ρ.tagname
          emit '^d135^', idx, name_openfinish, ρ.tagname
        ρ.data  = '';
        ρ.state = state_data;
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d136^', idx, name_info, chr
        ρ.has_slash = true
        ρ.state     = state_tag_end
        emit '^d137^', idx, name_open, ρ.tagname
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d138^', idx, name_info, chr
        ρ.tagname += chr
        if ρ.tagname is '![CDATA['
          emit '^d139^', idx, name_opencdata, ρ.tagname
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
        emit '^d140^', idx, name_info, chr
        if ρ.has_slash
          ρ.has_slash = false
          emit '^d141^', idx, name_solitary, ρ.tagname
        else
          emit '^d142^', idx, name_close, ρ.tagname
        ρ.data  = ''
        ρ.state = state_data
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d143^', idx, name_info, chr
        emit '^d144^', idx, name_extraneous, chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_start:
      #.....................................................................................................
      action_lt: ( idx, chr ) =>
        emit '^d145^', idx, name_info, chr
        emit '^d146^', idx, name_missingbracket, chr
        # emit '^d147^',  idx, name_openfinish, chr
        ρ.state     = state_tag_begin
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d148^', idx, name_info, chr
        ρ.atrl      = idx
        ρ.atrname   = chr
        ρ.state     = state_atrname
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d149^', idx, name_info, chr
        emit '^d150^',  idx, name_openfinish, chr
        ρ.data = ''
        ρ.state = state_data
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d151^', idx, name_info, chr
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d152^', idx, name_info, chr
        ρ.has_slash   = true
        ρ.is_closing  = true
        ρ.state       = state_tag_end

    #-------------------------------------------------------------------------------------------------------
    state_atrname:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d153^', idx, name_info, chr
        ρ.state = state_atrname_end
      #.....................................................................................................
      action_equal: ( idx, chr ) =>
        emit '^d154^', idx, name_info, chr
        emit '^d155^', idx, name_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d156^', idx, name_info, chr
        ρ.atrvalue = ''
        unless ρ.decl_syntax and ρ.atrname is '?'
          emit '^d157^', idx, name_atrname, ρ.atrname
          emit '^d158^', idx, name_atrvalue, ρ.atrvalue
        emit '^d159^', idx, name_openfinish, ρ.tagname
        ρ.data      = ''
        ρ.state     = state_data
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d160^', idx, name_info, chr
        ρ.has_slash   = true
        ρ.is_closing  = true
        ρ.atrvalue    = ''
        emit '^d161^', idx, name_atrname, ρ.atrname
        emit '^d162^', idx, name_atrvalue, ρ.atrvalue
        ρ.state = state_tag_end
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d163^', idx, name_info, chr
        ρ.atrname += chr

    #-------------------------------------------------------------------------------------------------------
    state_atrname_end:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d164^', idx, name_info, chr
        emit '^d165^', idx, name_noop, chr
      #.....................................................................................................
      action_equal: ( idx, chr ) =>
        emit '^d166^', idx, name_info, chr
        emit '^d167^', idx, name_atrname, ρ.atrname
        ρ.state = state_atrvalue_begin
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d168^', idx, name_info, chr
        ρ.atrvalue  = ''
        ρ.data      = ''
        emit '^d169^', idx, name_atrname, ρ.atrname
        emit '^d170^', idx, name_atrvalue, ρ.atrvalue
        emit '^d171^', idx, name_openfinish, ρ.tagname
        ρ.state     = state_data
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d172^', idx, name_info, chr
        ρ.atrvalue = ''
        emit '^d173^', idx, name_atrname, ρ.atrname
        emit '^d174^', idx, name_atrvalue, ρ.atrvalue
        ρ.atrname  = chr
        ρ.state     = state_atrname
    #-------------------------------------------------------------------------------------------------------
    state_atrvalue_begin:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d175^', idx, name_info, chr
      #.....................................................................................................
      action_quote: ( idx, chr ) =>
        emit '^d176^', idx, name_info, chr
        ρ.prv_quote  = chr
        ρ.atrvalue     = ''
        ρ.state         = state_atrvalue
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        emit '^d177^', idx, name_info, chr
        ρ.atrvalue     = ''
        emit '^d178^', idx, name_atrvalue, ρ.atrvalue
        ρ.data          = ''
        ρ.state         = state_data
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d179^', idx, name_info, chr
        ρ.prv_quote     = ''
        ρ.atrvalue      = chr
        ρ.state         = state_atrvalue

    #-------------------------------------------------------------------------------------------------------
    state_atrvalue:
      #.....................................................................................................
      action_space: ( idx, chr ) =>
        emit '^d180^', idx, name_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d181^', idx, name_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
      #.....................................................................................................
      action_quote: ( idx, chr ) =>
        emit '^d182^', idx, name_info, chr
        if chr is ρ.prv_quote
          emit '^d183^', idx, name_atrvalue, ρ.atrvalue
          ρ.state = state_atrname_start
        else
          ρ.atrvalue += chr
      #.....................................................................................................
      action_gt: ( idx, chr ) =>
        if ρ.prv_quote.length > 0
          emit '^d184^', idx, name_info, chr
          ρ.atrvalue += chr
        else
          emit '^d185^', idx, name_info, chr
          emit '^d186^', idx, name_atrvalue, ρ.atrvalue
          emit '^d187^', idx, name_openfinish, chr
          ρ.data  = ''
          ρ.state = state_data
        return null
      #.....................................................................................................
      action_slash: ( idx, chr ) =>
        emit '^d188^', idx, name_info, chr
        if ρ.prv_quote.length > 0
          ρ.atrvalue += chr
        else
          emit '^d189^', idx, name_atrvalue, ρ.atrvalue
          ρ.has_slash   = true
          ρ.is_closing  = true
          ρ.state       = state_tag_end
      #.....................................................................................................
      action_chr: ( idx, chr ) =>
        emit '^d190^', idx, name_info, chr
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




