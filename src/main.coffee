'use strict'


EventEmitter = require('eventemitter3')
{ isa
  validate
  type_of }               = ( new ( require 'intertype' ).Intertype() ).export()

State = {
  data:                   'state-data'
  cdata:                  'state-cdata'
  tagBegin:               'state-tag-begin'
  tagName:                'state-tag-name'
  tagEnd:                 'state-tag-end'
  attributeNameStart:     'state-attribute-name-start'
  attributeName:          'state-attribute-name'
  attributeNameEnd:       'state-attribute-name-end'
  attributeValueBegin:    'state-attribute-value-begin'
  attributeValue:         'state-attribute-value'
  }

Action = {
  lt:                     'action-lt'
  gt:                     'action-gt'
  space:                  'action-space'
  equal:                  'action-equal'
  quote:                  'action-quote'
  slash:                  'action-slash'
  chr:                    'action-chr'
  error:                  'action-error'
  }

Type = {
  text:                   'text'
  openTag:                'open'
  closeTag:               'close'
  attributeName:          'attribute-name'
  attributeValue:         'attribute-value'
  noop:                   'noop'
  }

charToAction = {
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
  }

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
  data              = ''
  tagName           = ''
  attrName          = ''
  attrValue         = ''
  isClosing         = false
  openingQuote      = ''

  #-----------------------------------------------------------------------------------------------------------
  action_from_chr = ( chr ) => charToAction[ chr ] ? Action.chr

  #---------------------------------------------------------------------------------------------------------
  step = ( src, idx, chr ) =>
    if settings.debug then console.log state, chr
    actions = lexer.stateMachine[ state ]
    action  = actions[ action_from_chr chr ] ? actions[ Action.error ] ? actions[ Action.chr ]
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
      return null if tagName[ 0 ] in '!?'
      return null if type is Type.noop
    # switch sigil = tagName[ 0 ]
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
        if data.trim().length > 0
          emit '^1^', src, idx, Type.text, data
        tagName = ''
        isClosing = false
        state = State.tagBegin
      #.....................................................................................................
      [Action.chr]: ( ( src, idx, chr ) => data += chr )

    #-------------------------------------------------------------------------------------------------------
    [State.cdata]:
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        data += chr
        if ( ( data.substr -3 ) is ']]>' )
          emit '^2^', src, idx, Type.text, data.slice 0, -3
          data  = ''
          state = State.data

    #-------------------------------------------------------------------------------------------------------
    [State.tagBegin]:
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^3^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        tagName = chr
        state   = State.tagName
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        tagName   = ''
        isClosing = true

    #-------------------------------------------------------------------------------------------------------
    [State.tagName]:
      #.....................................................................................................
      [Action.space]: ( src, idx, chr ) =>
        if isClosing
          state = State.tagEnd
        else
          state = State.attributeNameStart
          emit '^4^', src, idx, Type.openTag, tagName
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        if isClosing
          emit '^5^', src, idx, Type.closeTag, tagName
        else
          emit '^6^', src, idx, Type.openTag, tagName
        data  = '';
        state = State.data;
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        state = State.tagEnd
        emit '^7^', src, idx, Type.openTag, tagName
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        tagName += chr
        if tagName is '![CDATA['
          state   = State.cdata
          data    = ''
          tagName = ''

    #-------------------------------------------------------------------------------------------------------
    [State.tagEnd]:
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        emit '^8^', src, idx, Type.closeTag, tagName
        data  = ''
        state = State.data
      #.....................................................................................................
      [Action.chr]: ( ( src, idx, chr ) => emit '^9^', src, idx, Type.noop, chr )

    #-------------------------------------------------------------------------------------------------------
    [State.attributeNameStart]:
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        attrName  = chr
        state     = State.attributeName
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        data = ''
        state = State.data
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^10^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        isClosing = true
        state     = State.tagEnd

    #-------------------------------------------------------------------------------------------------------
    [State.attributeName]:
      #.....................................................................................................
      [Action.space]: ( src, idx, chr ) =>
        state = State.attributeNameEnd
      #.....................................................................................................
      [Action.equal]: ( src, idx, chr ) =>
        emit '^11^', src, idx, Type.attributeName, attrName
        state = State.attributeValueBegin
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        attrValue = ''
        emit '^12^', src, idx, Type.attributeName, attrName
        emit '^13^', src, idx, Type.attributeValue, attrValue
        data      = ''
        state     = State.data
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        isClosing = true
        attrValue = ''
        emit '^14^', src, idx, Type.attributeName, attrName
        emit '^15^', src, idx, Type.attributeValue, attrValue
        state = State.tagEnd
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        attrName += chr

    #-------------------------------------------------------------------------------------------------------
    [State.attributeNameEnd]:
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^16^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.equal]: ( src, idx, chr ) =>
        emit '^17^', src, idx, Type.attributeName, attrName
        state = State.attributeValueBegin
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        attrValue = ''
        emit '^18^', src, idx, Type.attributeName, attrName
        emit '^19^', src, idx, Type.attributeValue, attrValue
        data      = ''
        state     = State.data
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        attrValue = ''
        emit '^20^', src, idx, Type.attributeName, attrName
        emit '^21^', src, idx, Type.attributeValue, attrValue
        attrName  = chr
        state     = State.attributeName

    #-------------------------------------------------------------------------------------------------------
    [State.attributeValueBegin]:
      #.....................................................................................................
      [Action.space]: ( ( src, idx, chr ) => emit '^22^', src, idx, Type.noop, chr )
      #.....................................................................................................
      [Action.quote]: ( src, idx, chr ) =>
        openingQuote  = chr
        attrValue     = ''
        state         = State.attributeValue
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        attrValue     = ''
        emit '^23^', src, idx, Type.attributeValue, attrValue
        data          = ''
        state         = State.data
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        openingQuote  = ''
        attrValue     = chr
        state         = State.attributeValue

    #-------------------------------------------------------------------------------------------------------
    [State.attributeValue]:
      #.....................................................................................................
      [Action.space]: ( src, idx, chr ) =>
        if openingQuote
          attrValue += chr
        else
          emit '^24^', src, idx, Type.attributeValue, attrValue
          state = State.attributeNameStart
      #.....................................................................................................
      [Action.quote]: ( src, idx, chr ) =>
        if openingQuote is chr
          emit '^25^', src, idx, Type.attributeValue, attrValue
          state = State.attributeNameStart
        else
          attrValue += chr
      #.....................................................................................................
      [Action.gt]: ( src, idx, chr ) =>
        if openingQuote
          attrValue += chr
        else
          emit '^26^', src, idx, Type.attributeValue, attrValue
          data  = ''
          state = State.data
      #.....................................................................................................
      [Action.slash]: ( src, idx, chr ) =>
        if openingQuote
          attrValue += chr
        else
          emit '^27^', src, idx, Type.attributeValue, attrValue
          isClosing = true
          state     = State.tagEnd
      #.....................................................................................................
      [Action.chr]: ( src, idx, chr ) =>
        attrValue += chr

  #---------------------------------------------------------------------------------------------------------
  return lexer


module.exports = { State, Action, Type, create, }




