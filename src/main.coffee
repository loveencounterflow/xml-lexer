'use strict'

noop = ->

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
  openTag:                'open-tag'
  closeTag:               'close-tag'
  attributeName:          'attribute-name'
  attributeValue:         'attribute-value'
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
action_from_chr = ( chr ) => charToAction[ chr ] ? Action.chr

#-----------------------------------------------------------------------------------------------------------
create = ( settings, handler ) ->
  switch arity = arguments.length
    when 1 then [ settings, handler, ] = [ null, settings, ]
    when 2 then null
    else throw new Error "^55563^ expected 1 or 2 arguments, got #{arity}"
  ### TAINT validate.xmllexer_settings settings ? {} ###
  ### TAINT validate.function handler ###
  settings          = { { debug: false, }..., settings..., }
  lexer             = new EventEmitter()
  state             = State.data
  data              = ''
  tagName           = ''
  attrName          = ''
  attrValue         = ''
  isClosing         = false
  openingQuote      = ''

  #---------------------------------------------------------------------------------------------------------
  step = ( chr ) =>
    if settings.debug then console.log '-->', state, chr
    actions = lexer.stateMachine[ state ]
    action  = actions[ action_from_chr chr ] ? actions[ Action.error ] ? actions[ Action.chr ]
    action chr
    return null

  #---------------------------------------------------------------------------------------------------------
  lexer.write = ( str ) =>
    len = str.length
    for i in [ 0 ... len ]
      step str[ i ]
    return null

  #---------------------------------------------------------------------------------------------------------
  emit = ( type, value ) =>
    # tags like: '?xml', '!DOCTYPE', comments
    # if ( first_chr = tagName[ 0 ] ) in '?!'
    #   return null
    event = { type, value }
    console.log 'emit:', event if settings.debug
    handler event

  ```
  lexer.stateMachine = {
    [State.data]: {
      [Action.lt]: () => {
        if (data.trim()) {
          emit(Type.text, data);
        }
        tagName = '';
        isClosing = false;
        state = State.tagBegin;
      },
      [Action.chr]: (chr) => {
        data += chr;
      },
    },
    [State.cdata]: {
      [Action.chr]: (chr) => {
        data += chr;
        if (data.substr(-3) === ']]>') {
          emit(Type.text, data.slice(0, -3));
          data = '';
          state = State.data;
        }
      },
    },
    [State.tagBegin]: {
      [Action.space]: noop,
      [Action.chr]: (chr) => {
        tagName = chr;
        state = State.tagName;
      },
      [Action.slash]: () => {
        tagName = '';
        isClosing = true;
      },
    },
    [State.tagName]: {
      [Action.space]: () => {
        if (isClosing) {
          state = State.tagEnd;
        } else {
          state = State.attributeNameStart;
          emit(Type.openTag, tagName);
        }
      },
      [Action.gt]: () => {
        if (isClosing) {
          emit(Type.closeTag, tagName);
        } else {
          emit(Type.openTag, tagName);
        }
        data = '';
        state = State.data;
      },
      [Action.slash]: () => {
        state = State.tagEnd;
        emit(Type.openTag, tagName);
      },
      [Action.chr]: (chr) => {
        tagName += chr;
        if (tagName === '![CDATA[') {
          state = State.cdata;
          data = '';
          tagName = '';
        }
      },
    },
    [State.tagEnd]: {
      [Action.gt]: () => {
        emit(Type.closeTag, tagName);
        data = '';
        state = State.data;
      },
      [Action.chr]: noop,
    },
    [State.attributeNameStart]: {
      [Action.chr]: (chr) => {
        attrName = chr;
        state = State.attributeName;
      },
      [Action.gt]: () => {
        data = '';
        state = State.data;
      },
      [Action.space]: noop,
      [Action.slash]: () => {
        isClosing = true;
        state = State.tagEnd;
      },
    },
    [State.attributeName]: {
      [Action.space]: () => {
        state = State.attributeNameEnd;
      },
      [Action.equal]: () => {
        emit(Type.attributeName, attrName);
        state = State.attributeValueBegin;
      },
      [Action.gt]: () => {
        attrValue = '';
        emit(Type.attributeName, attrName);
        emit(Type.attributeValue, attrValue);
        data = '';
        state = State.data;
      },
      [Action.slash]: () => {
        isClosing = true;
        attrValue = '';
        emit(Type.attributeName, attrName);
        emit(Type.attributeValue, attrValue);
        state = State.tagEnd;
      },
      [Action.chr]: (chr) => {
        attrName += chr;
      },
    },
    [State.attributeNameEnd]: {
      [Action.space]: noop,
      [Action.equal]: () => {
        emit(Type.attributeName, attrName);
        state = State.attributeValueBegin;
      },
      [Action.gt]: () => {
        attrValue = '';
        emit(Type.attributeName, attrName);
        emit(Type.attributeValue, attrValue);
        data = '';
        state = State.data;
      },
      [Action.chr]: (chr) => {
        attrValue = '';
        emit(Type.attributeName, attrName);
        emit(Type.attributeValue, attrValue);
        attrName = chr;
        state = State.attributeName;
      },
    },
    [State.attributeValueBegin]: {
      [Action.space]: noop,
      [Action.quote]: (chr) => {
        openingQuote = chr;
        attrValue = '';
        state = State.attributeValue;
      },
      [Action.gt]: () => {
        attrValue = '';
        emit(Type.attributeValue, attrValue);
        data = '';
        state = State.data;
      },
      [Action.chr]: (chr) => {
        openingQuote = '';
        attrValue = chr;
        state = State.attributeValue;
      },
    },
    [State.attributeValue]: {
      [Action.space]: (chr) => {
        if (openingQuote) {
          attrValue += chr;
        } else {
          emit(Type.attributeValue, attrValue);
          state = State.attributeNameStart;
        }
      },
      [Action.quote]: (chr) => {
        if (openingQuote === chr) {
          emit(Type.attributeValue, attrValue);
          state = State.attributeNameStart;
        } else {
          attrValue += chr;
        }
      },
      [Action.gt]: (chr) => {
        if (openingQuote) {
          attrValue += chr;
        } else {
          emit(Type.attributeValue, attrValue);
          data = '';
          state = State.data;
        }
      },
      [Action.slash]: (chr) => {
        if (openingQuote) {
          attrValue += chr;
        } else {
          emit(Type.attributeValue, attrValue);
          isClosing = true;
          state = State.tagEnd;
        }
      },
      [Action.chr]: (chr) => {
        attrValue += chr;
      },
    },
  };


  ```
  return lexer


module.exports = { State, Action, Type, create, }




