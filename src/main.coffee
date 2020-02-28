'use strict'


EventEmitter = require('eventemitter3')
{ isa
  validate
  type_of }               = ( new ( require 'intertype' ).Intertype() ).export()

State =
  data:                   'state-data'
  cdata:                  'state-cdata'
  tagBegin:               'state-tag-begin'
  tag_name:               'state-tag-name'
  tagEnd:                 'state-tag-end'
  attributeNameStart:     'state-attribute-name-start'
  attributeName:          'state-attribute-name'
  attributeNameEnd:       'state-attribute-name-end'
  attributeValueBegin:    'state-attribute-value-begin'
  attributeValue:         'state-attribute-value'

Action =
  lt:                     'action-lt'
  gt:                     'action-gt'
  space:                  'action-space'
  equal:                  'action-equal'
  quote:                  'action-quote'
  slash:                  'action-slash'
  chr:                    'action-chr'
  error:                  'action-error'

Type =
  text:                   'text'
  openTag:                'open'
  closeTag:               'close'
  attributeName:          'attribute-name'
  attributeValue:         'attribute-value'
  noop:                   'noop'

actions_by_chrs =
  ' ':                    Action.space
  '\t':                   Action.space
  '\n':                   Action.space
  '\r':                   Action.space
  '<':                    Action.lt
  '>':                    Action.gt
  '"':                    Action.quote
  "'":                    Action.quote
  '=':                    Action.equal
  '/':                    Action.slash

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
  state             = State.data

  #---------------------------------------------------------------------------------------------------------
  # Registers
  #---------------------------------------------------------------------------------------------------------
  ρ =
    data:           ''
    tag_name:       ''
    attr_name:      ''
    atr_value:      ''
    is_closing:     false
    prv_quote:      ''

  #---------------------------------------------------------------------------------------------------------
  step = ( src, idx, chr ) =>
    if settings.debug then console.log state, chr
    actions = lexer.stateMachine[ state ]
    action  = actions[ actions_by_chrs[ chr ] ? Action.chr ] ? actions[ Action.error ] ? actions[ Action.chr ]
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
      return null if ρ.tag_name[ 0 ] in '!?'
      return null if type is Type.noop
    # switch sigil = ρ.tag_name[ 0 ]
    #   when '?' then type = ''
    #   when '!' then type = 'declaration'
    # event.sigil = sigil if sigil?
    event = { ref, type, value }
    if handler? then  handler { ref, idx, type, value, }
    else              lexer.emit 'data', { type, value, }

  lexer.stateMachine =

    #-------------------------------------------------------------------------------------------------------
    [State.data]:
      #.....................................................................................................
      [Action.lt]: ( src, idx, chr ) =>
        if ρ.data.trim().length > 0
          emit '^1^', src, idx, Type.text, ρ.data
        ρ.tag_name   = ''
        ρ.is_closing = false
        state     = State.tagBegin
      #.....................................................................................................
      [Action.chr]: ( ( src, idx, chr ) => ρ.data += chr )

    #-------------------------------------------------------------------------------------------------------
    [State.cdata]:
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.data += chr
        if ( ( ρ.data.substr -3 ) is ']]>' )
          emit '^2^', src, idx, Type.text, ρ.data.slice 0, -3
          ρ.data  = ''
          state = State.data

    #-------------------------------------------------------------------------------------------------------
    [State.tagBegin]:
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^3^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.tag_name = chr
        state   = State.tag_name
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        ρ.tag_name   = ''
        ρ.is_closing = true

    #-------------------------------------------------------------------------------------------------------
    [State.tag_name]:
      #.....................................................................................................
      [Action.space]: ( src, idx, chr ) =>
        if ρ.is_closing
          state = State.tagEnd
        else
          state = State.attributeNameStart
          emit '^4^', src, idx, Type.openTag, ρ.tag_name
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        if ρ.is_closing
          emit '^5^', src, idx, Type.closeTag, ρ.tag_name
        else
          emit '^6^', src, idx, Type.openTag, ρ.tag_name
        ρ.data  = '';
        state = State.data;
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        state = State.tagEnd
        emit '^7^', src, idx, Type.openTag, ρ.tag_name
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.tag_name += chr
        if ρ.tag_name is '![CDATA['
          state   = State.cdata
          ρ.data    = ''
          ρ.tag_name = ''

    #-------------------------------------------------------------------------------------------------------
    [State.tagEnd]:
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        emit '^8^', src, idx, Type.closeTag, ρ.tag_name
        ρ.data  = ''
        state = State.data
      #.....................................................................................................
      [Action.chr]: ( ( src, idx, chr ) => emit '^9^', src, idx, Type.noop, chr )

    #-------------------------------------------------------------------------------------------------------
    [State.attributeNameStart]:
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.attr_name  = chr
        state     = State.attributeName
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        ρ.data = ''
        state = State.data
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^10^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        ρ.is_closing = true
        state     = State.tagEnd

    #-------------------------------------------------------------------------------------------------------
    [State.attributeName]:
      #.....................................................................................................
      [Action.space]: ( src, idx, chr ) =>
        state = State.attributeNameEnd
      #.....................................................................................................
      [Action.equal]: ( src, idx, chr ) =>
        emit '^11^', src, idx, Type.attributeName, ρ.attr_name
        state = State.attributeValueBegin
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        ρ.atr_value = ''
        emit '^12^', src, idx, Type.attributeName, ρ.attr_name
        emit '^13^', src, idx, Type.attributeValue, ρ.atr_value
        ρ.data      = ''
        state     = State.data
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        ρ.is_closing = true
        ρ.atr_value = ''
        emit '^14^', src, idx, Type.attributeName, ρ.attr_name
        emit '^15^', src, idx, Type.attributeValue, ρ.atr_value
        state = State.tagEnd
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.attr_name += chr

    #-------------------------------------------------------------------------------------------------------
    [State.attributeNameEnd]:
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^16^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.equal]: ( src, idx, chr ) =>
        emit '^17^', src, idx, Type.attributeName, ρ.attr_name
        state = State.attributeValueBegin
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        ρ.atr_value = ''
        emit '^18^', src, idx, Type.attributeName, ρ.attr_name
        emit '^19^', src, idx, Type.attributeValue, ρ.atr_value
        ρ.data      = ''
        state     = State.data
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.atr_value = ''
        emit '^20^', src, idx, Type.attributeName, ρ.attr_name
        emit '^21^', src, idx, Type.attributeValue, ρ.atr_value
        ρ.attr_name  = chr
        state     = State.attributeName

    #-------------------------------------------------------------------------------------------------------
    [State.attributeValueBegin]:
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^22^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.quote]: ( src, idx, chr ) =>
        ρ.prv_quote  = chr
        ρ.atr_value     = ''
        state         = State.attributeValue
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        ρ.atr_value     = ''
        emit '^23^', src, idx, Type.attributeValue, ρ.atr_value
        ρ.data          = ''
        state         = State.data
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.prv_quote  = ''
        ρ.atr_value     = chr
        state         = State.attributeValue

    #-------------------------------------------------------------------------------------------------------
    [State.attributeValue]:
      #.....................................................................................................
      [Action.space]: ( src, idx, chr ) =>
        if ρ.prv_quote.length > 0
          ρ.atr_value += chr
        else
          emit '^24^', src, idx, Type.attributeValue, ρ.atr_value
          state = State.attributeNameStart
      #.....................................................................................................
      [Action.quote]: ( src, idx, chr ) =>
        if chr is ρ.prv_quote
          emit '^25^', src, idx, Type.attributeValue, ρ.atr_value
          state = State.attributeNameStart
        else
          ρ.atr_value += chr
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        if ρ.prv_quote.length > 0
          ρ.atr_value += chr
        else
          emit '^26^', src, idx, Type.attributeValue, ρ.atr_value
          ρ.data  = ''
          state = State.data
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        if ρ.prv_quote.length > 0
          ρ.atr_value += chr
        else
          emit '^27^', src, idx, Type.attributeValue, ρ.atr_value
          ρ.is_closing = true
          state     = State.tagEnd
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        ρ.atr_value += chr

  #---------------------------------------------------------------------------------------------------------
  return lexer


module.exports = { State, Action, Type, create, }




