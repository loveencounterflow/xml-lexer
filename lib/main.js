// Generated by CoffeeScript 2.5.1
(function() {
  'use strict';
  'use strict';
  var CND, DATOM, action_chr, action_equal, action_error, action_gt, action_lt, action_quote, action_slash, action_space, actions_by_chrs, alert, assign, badge, create, debug, echo, freeze, help, info, isa, jr, lets, log, name_atrname, name_atrvalue, name_close, name_closecdata, name_comment, name_extraneous, name_info, name_missingbracket, name_noop, name_open, name_opencdata, name_openfinish, name_solitary, name_text, name_unfinishedtag, new_datom, rpr, select, state_atrname, state_atrname_end, state_atrname_start, state_atrvalue, state_atrvalue_begin, state_cdata, state_comment, state_data, state_tag_begin, state_tag_end, state_tagname, type_of, urge, validate, warn, whisper, wrap_datom,
    indexOf = [].indexOf;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'XML-LEXER';

  log = CND.get_logger('plain', badge);

  info = CND.get_logger('info', badge);

  whisper = CND.get_logger('whisper', badge);

  alert = CND.get_logger('alert', badge);

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  help = CND.get_logger('help', badge);

  urge = CND.get_logger('urge', badge);

  echo = CND.echo.bind(CND);

  //...........................................................................................................
  ({assign, jr} = CND);

  //...........................................................................................................
  DATOM = new (require('datom')).Datom({
    dirty: false
  });

  ({new_datom, wrap_datom, lets, freeze, select} = DATOM.export());

  ({isa, validate, type_of} = (new (require('intertype')).Intertype()).export());

  state_data = 'state_data';

  state_cdata = 'state_cdata';

  state_comment = 'state_comment';

  state_tag_begin = 'state_tag_begin';

  state_tagname = 'state_tagname';

  state_tag_end = 'state_tag_end';

  state_atrname_start = 'state_atrname_start';

  state_atrname = 'state_atrname';

  state_atrname_end = 'state_atrname_end';

  state_atrvalue_begin = 'state_atrvalue_begin';

  state_atrvalue = 'state_atrvalue';

  action_lt = 'action_lt';

  action_gt = 'action_gt';

  action_space = 'action_space';

  action_equal = 'action_equal';

  action_quote = 'action_quote';

  action_slash = 'action_slash';

  action_chr = 'action_chr';

  action_error = 'action_error';

  name_text = 'text';

  name_open = 'open';

  name_openfinish = 'openfinish';

  name_opencdata = 'opencdata';

  name_close = 'close';

  name_closecdata = 'closecdata';

  name_comment = 'comment';

  name_atrname = 'atrname';

  name_atrvalue = 'atrvalue';

  name_extraneous = 'extraneous';

  name_solitary = 'solitary';

  name_missingbracket = 'missingbracket';

  name_unfinishedtag = 'unfinishedtag';

  //...........................................................................................................
  name_noop = 'noop';

  name_info = 'info';

  // name_sot                = 'sot' # Start Of Text
  actions_by_chrs = {
    ' ': action_space,
    '\t': action_space,
    '\n': action_space,
    '\r': action_space,
    '<': action_lt,
    '>': action_gt,
    '"': action_quote,
    "'": action_quote,
    '=': action_equal,
    '/': action_slash
  };

  //-----------------------------------------------------------------------------------------------------------
  create = function(settings, handler) {
    /* TAINT validate.xmllexer_settings settings ? {} */
    /* TAINT validate.function handler */
    var arity, defaults, emit, lexer, step, ρ;
    switch (arity = arguments.length) {
      case 0:
        null;
        break;
      case 1:
        [settings, handler] = [null, settings];
        break;
      case 2:
        null;
        break;
      default:
        throw new Error(`^55563^ expected 1 or 2 arguments, got ${arity}`);
    }
    if (!isa.function(handler)) {
      [settings, handler] = [handler, null];
    }
    defaults = {
      include_specials: false,
      emit_info: false,
      emit_noop: false
    };
    settings = {...defaults, ...settings};
    lexer = {};
    //---------------------------------------------------------------------------------------------------------
    // Registers
    //---------------------------------------------------------------------------------------------------------
    ρ = {
      state: state_data,
      data: '',
      tagname: '',
      atrname: '',
      atrvalue: '',
      is_closing: false,
      prv_quote: '',
      has_slash: false,
      txtl: null, // first index of current or most recent text ('data' or 'cdata') stretch
      tagl: null, // first index of current or most recent tag
      tagr: null, // last index of current or most recent tag
      atrl: null, // first index of either atrname or atrvalue
      decl_syntax: false, // true if tag opened with `<?`
      src: null,
      max_idx: null
    };
    //---------------------------------------------------------------------------------------------------------
    step = (idx, chr) => {
      var action, actions, ref1, ref2, ref3;
      if (settings.debug) {
        console.log(ρ.state, chr);
      }
      actions = lexer.stateMachine[ρ.state];
      action = (ref1 = (ref2 = actions[(ref3 = actions_by_chrs[chr]) != null ? ref3 : action_chr]) != null ? ref2 : actions[action_error]) != null ? ref1 : actions[action_chr];
      action(idx, chr);
      return null;
    };
    //---------------------------------------------------------------------------------------------------------
    lexer.write = (src) => {
      var i, idx, ref1;
      ρ.max_idx = 0;
      ρ.src = src;
      for (idx = i = 0, ref1 = src.length; (0 <= ref1 ? i < ref1 : i > ref1); idx = 0 <= ref1 ? ++i : --i) {
        step(idx, src[idx]);
      }
      return null;
    };
    //---------------------------------------------------------------------------------------------------------
    lexer.flush = () => {
      var idx, ref1, ref2, ref3, ref4, ref5, ref6, ref7, ref8, ref9;
      if (!(ρ.max_idx < ρ.src.length - 1)) {
        // debug '^4445^', ρ.max_idx, ρ.src.length
        // debug '^4445^', ρ.state
        // debug '^4445^', ρ
        return null;
      }
      idx = ρ.src.length - 1;
      switch (ρ.state) {
        case state_atrvalue_begin:
        case state_atrvalue:
          emit('^d1^', idx, name_atrvalue, ρ.atrvalue);
          emit('^d2^', idx, name_openfinish, (ref1 = ρ.tagname) != null ? ref1 : '');
          emit('^d3^', idx, name_unfinishedtag, '');
          break;
        case state_atrname:
          emit('^d4^', idx, name_atrname, (ref2 = ρ.atrname) != null ? ref2 : '');
          emit('^d5^', idx, name_atrvalue, (ref3 = ρ.atrvalue) != null ? ref3 : '');
          emit('^d6^', idx, name_openfinish, (ref4 = ρ.tagname) != null ? ref4 : '');
          emit('^d7^', idx, name_unfinishedtag, '');
          break;
        case state_atrname_start:
        case state_tagname:
          emit('^d10^', idx, name_open, (ref5 = ρ.tagname) != null ? ref5 : '');
          emit('^d8^', idx, name_openfinish, (ref6 = ρ.tagname) != null ? ref6 : '');
          emit('^d9^', idx, name_unfinishedtag, '');
          break;
        case state_tag_begin:
          emit('^d10^', idx, name_open, '');
          emit('^d11^', idx, name_openfinish, '');
          emit('^d12^', idx, name_unfinishedtag, '');
          break;
        case state_data:
          emit('^d13^', idx, name_text, (ref7 = ρ.data) != null ? ref7 : '');
          if (ρ.data.endsWith('>')) {
            emit('^d12^', idx, name_extraneous, '');
          }
          break;
        case state_cdata:
          emit('^d13^', idx, name_text, (ref8 = ρ.data) != null ? ref8 : '');
          emit('^d12^', idx, name_unfinishedtag, '');
          break;
        case state_comment:
          emit('^d13^', idx, name_text, '<!--' + ((ref9 = ρ.data) != null ? ref9 : ''));
          emit('^d12^', idx, name_unfinishedtag, '');
          break;
        default:
          throw new Error(`^4455^ unable to deal with pending state ${ρ.state}`);
      }
      return null;
    };
    //---------------------------------------------------------------------------------------------------------
    emit = (ref, idx, name, text) => {
      var atrl, has_slash, ref1, stop, tagl, tagr, txtl;
      if (name !== name_noop && name !== name_info) {
        // sigil = null
        // # tags like: '?xml', '!DOCTYPE', comments
        ρ.max_idx = idx;
      }
      if ((name === name_noop) && (!settings.emit_noop)) {
        return null;
      }
      if ((name === name_info) && (!settings.emit_info)) {
        return null;
      }
      if (!settings.include_specials) {
        if (ref1 = ρ.tagname[0], indexOf.call('!?', ref1) >= 0) {
          return null;
        }
        if (name === name_noop) {
          return null;
        }
      }
      ({txtl, tagl, tagr, atrl, has_slash} = ρ);
      stop = idx;
      handler(new_datom('^raw', {
        name,
        text,
        stop,
        txtl,
        tagl,
        tagr,
        atrl,
        has_slash,
        $: ref
      }));
      return null;
    };
    lexer.stateMachine = {
      //-------------------------------------------------------------------------------------------------------
      state_data: {
        //.....................................................................................................
        action_lt: (idx, chr) => {
          emit('^d14^', idx, name_info, chr);
          if (ρ.data.length > 0) {
            emit('^d15^', idx, name_text, ρ.data);
          }
          ρ.tagl = idx;
          ρ.tagname = '';
          ρ.is_closing = false;
          return ρ.state = state_tag_begin;
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d16^', idx, name_info, chr);
          if (ρ.data === '') {
            ρ.txtl = idx;
          }
          return ρ.data += chr;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_cdata: {
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d17^', idx, name_info, chr);
          if (ρ.data === '') {
            ρ.txtl = idx;
          }
          ρ.data += chr;
          if ((ρ.data.substr(-3)) === ']]>') {
            ρ.tagl = idx - 2;
            emit('^d18^', idx, name_text, ρ.data.slice(0, -3));
            emit('^d19^', idx, name_closecdata, ρ.data.slice(-3));
            ρ.data = '';
            ρ.state = state_data;
          }
          return null;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_comment: {
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d20^', idx, name_info, chr);
          if (ρ.data === '') {
            ρ.txtl = idx - 4;
          }
          ρ.data += chr;
          if ((ρ.data.substr(-3)) === '-->') {
            ρ.tagl = idx - 2;
            emit('^d21^', idx, name_comment, '<!--' + ρ.data);
            ρ.data = '';
            ρ.state = state_data;
          }
          return null;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_tag_begin: {
        //.....................................................................................................
        action_space: (idx, chr) => {
          return emit('^d22^', idx, name_info, chr);
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d23^', idx, name_info, chr);
          ρ.decl_syntax = chr === '?';
          ρ.tagname = chr;
          return ρ.state = state_tagname;
        },
        //.....................................................................................................
        action_slash: (idx, chr) => {
          emit('^d24^', idx, name_info, chr);
          ρ.tagname = '';
          return ρ.is_closing = true;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_tagname: {
        //.....................................................................................................
        action_space: (idx, chr) => {
          emit('^d25^', idx, name_info, chr);
          if (ρ.is_closing) {
            return ρ.state = state_tag_end;
          } else {
            ρ.state = state_atrname_start;
            return emit('^d26^', idx, name_open, ρ.tagname);
          }
        },
        //.....................................................................................................
        action_gt: (idx, chr) => {
          emit('^d27^', idx, name_info, chr);
          if (ρ.is_closing) {
            ρ.tagr = idx + 1;
            emit('^d28^', idx, name_close, ρ.tagname);
          } else {
            emit('^d29^', idx, name_open, ρ.tagname);
            emit('^d30^', idx, name_openfinish, ρ.tagname);
          }
          ρ.data = '';
          return ρ.state = state_data;
        },
        //.....................................................................................................
        action_slash: (idx, chr) => {
          emit('^d31^', idx, name_info, chr);
          ρ.has_slash = true;
          ρ.state = state_tag_end;
          return emit('^d32^', idx, name_open, ρ.tagname);
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d33^', idx, name_info, chr);
          ρ.tagname += chr;
          if (ρ.tagname === '![CDATA[') {
            emit('^d34^', idx, name_opencdata, ρ.tagname);
            ρ.state = state_cdata;
            ρ.data = '';
            ρ.tagname = '';
          } else if (ρ.tagname === '!--') {
            ρ.state = state_comment;
            ρ.data = '';
            ρ.tagname = '';
          }
          return null;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_tag_end: {
        //.....................................................................................................
        action_gt: (idx, chr) => {
          emit('^d35^', idx, name_info, chr);
          if (ρ.has_slash) {
            ρ.has_slash = false;
            emit('^d36^', idx, name_solitary, ρ.tagname);
          } else {
            emit('^d37^', idx, name_close, ρ.tagname);
          }
          ρ.data = '';
          return ρ.state = state_data;
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d38^', idx, name_info, chr);
          return emit('^d39^', idx, name_extraneous, chr);
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_atrname_start: {
        //.....................................................................................................
        action_lt: (idx, chr) => {
          emit('^d40^', idx, name_info, chr);
          emit('^d41^', idx, name_missingbracket, chr);
          // emit '^d42^',  idx, name_openfinish, chr
          return ρ.state = state_tag_begin;
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d43^', idx, name_info, chr);
          ρ.atrl = idx;
          ρ.atrname = chr;
          return ρ.state = state_atrname;
        },
        //.....................................................................................................
        action_gt: (idx, chr) => {
          emit('^d44^', idx, name_info, chr);
          emit('^d45^', idx, name_openfinish, chr);
          ρ.data = '';
          return ρ.state = state_data;
        },
        //.....................................................................................................
        action_space: (idx, chr) => {
          return emit('^d46^', idx, name_info, chr);
        },
        //.....................................................................................................
        action_slash: (idx, chr) => {
          emit('^d47^', idx, name_info, chr);
          ρ.has_slash = true;
          ρ.is_closing = true;
          return ρ.state = state_tag_end;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_atrname: {
        //.....................................................................................................
        action_space: (idx, chr) => {
          emit('^d48^', idx, name_info, chr);
          return ρ.state = state_atrname_end;
        },
        //.....................................................................................................
        action_equal: (idx, chr) => {
          emit('^d49^', idx, name_info, chr);
          emit('^d50^', idx, name_atrname, ρ.atrname);
          return ρ.state = state_atrvalue_begin;
        },
        //.....................................................................................................
        action_gt: (idx, chr) => {
          emit('^d51^', idx, name_info, chr);
          ρ.atrvalue = '';
          if (!(ρ.decl_syntax && ρ.atrname === '?')) {
            emit('^d52^', idx, name_atrname, ρ.atrname);
            emit('^d53^', idx, name_atrvalue, ρ.atrvalue);
          }
          emit('^d54^', idx, name_openfinish, ρ.tagname);
          ρ.data = '';
          return ρ.state = state_data;
        },
        //.....................................................................................................
        action_slash: (idx, chr) => {
          emit('^d55^', idx, name_info, chr);
          ρ.has_slash = true;
          ρ.is_closing = true;
          ρ.atrvalue = '';
          emit('^d56^', idx, name_atrname, ρ.atrname);
          emit('^d57^', idx, name_atrvalue, ρ.atrvalue);
          return ρ.state = state_tag_end;
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d58^', idx, name_info, chr);
          return ρ.atrname += chr;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_atrname_end: {
        //.....................................................................................................
        action_space: (idx, chr) => {
          emit('^d59^', idx, name_info, chr);
          return emit('^d60^', idx, name_noop, chr);
        },
        //.....................................................................................................
        action_equal: (idx, chr) => {
          emit('^d61^', idx, name_info, chr);
          emit('^d62^', idx, name_atrname, ρ.atrname);
          return ρ.state = state_atrvalue_begin;
        },
        //.....................................................................................................
        action_gt: (idx, chr) => {
          emit('^d63^', idx, name_info, chr);
          ρ.atrvalue = '';
          ρ.data = '';
          emit('^d64^', idx, name_atrname, ρ.atrname);
          emit('^d65^', idx, name_atrvalue, ρ.atrvalue);
          emit('^d66^', idx, name_openfinish, ρ.tagname);
          return ρ.state = state_data;
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d67^', idx, name_info, chr);
          ρ.atrvalue = '';
          emit('^d68^', idx, name_atrname, ρ.atrname);
          emit('^d69^', idx, name_atrvalue, ρ.atrvalue);
          ρ.atrname = chr;
          return ρ.state = state_atrname;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_atrvalue_begin: {
        //.....................................................................................................
        action_space: (idx, chr) => {
          return emit('^d70^', idx, name_info, chr);
        },
        //.....................................................................................................
        action_quote: (idx, chr) => {
          emit('^d71^', idx, name_info, chr);
          ρ.prv_quote = chr;
          ρ.atrvalue = '';
          return ρ.state = state_atrvalue;
        },
        //.....................................................................................................
        action_gt: (idx, chr) => {
          emit('^d72^', idx, name_info, chr);
          ρ.atrvalue = '';
          emit('^d73^', idx, name_atrvalue, ρ.atrvalue);
          ρ.data = '';
          return ρ.state = state_data;
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d74^', idx, name_info, chr);
          ρ.prv_quote = '';
          ρ.atrvalue = chr;
          return ρ.state = state_atrvalue;
        }
      },
      //-------------------------------------------------------------------------------------------------------
      state_atrvalue: {
        //.....................................................................................................
        action_space: (idx, chr) => {
          emit('^d75^', idx, name_info, chr);
          if (ρ.prv_quote.length > 0) {
            return ρ.atrvalue += chr;
          } else {
            emit('^d76^', idx, name_atrvalue, ρ.atrvalue);
            return ρ.state = state_atrname_start;
          }
        },
        //.....................................................................................................
        action_quote: (idx, chr) => {
          emit('^d77^', idx, name_info, chr);
          if (chr === ρ.prv_quote) {
            emit('^d78^', idx, name_atrvalue, ρ.atrvalue);
            return ρ.state = state_atrname_start;
          } else {
            return ρ.atrvalue += chr;
          }
        },
        //.....................................................................................................
        action_gt: (idx, chr) => {
          if (ρ.prv_quote.length > 0) {
            emit('^d79^', idx, name_info, chr);
            ρ.atrvalue += chr;
          } else {
            emit('^d80^', idx, name_info, chr);
            emit('^d81^', idx, name_atrvalue, ρ.atrvalue);
            emit('^d82^', idx, name_openfinish, chr);
            ρ.data = '';
            ρ.state = state_data;
          }
          return null;
        },
        //.....................................................................................................
        action_slash: (idx, chr) => {
          emit('^d83^', idx, name_info, chr);
          if (ρ.prv_quote.length > 0) {
            return ρ.atrvalue += chr;
          } else {
            emit('^d84^', idx, name_atrvalue, ρ.atrvalue);
            ρ.has_slash = true;
            ρ.is_closing = true;
            return ρ.state = state_tag_end;
          }
        },
        //.....................................................................................................
        action_chr: (idx, chr) => {
          emit('^d85^', idx, name_info, chr);
          return ρ.atrvalue += chr;
        }
      }
    };
    //---------------------------------------------------------------------------------------------------------
    return lexer;
  };

  module.exports = {state_data, state_cdata, state_tag_begin, state_tagname, state_tag_end, state_atrname_start, state_atrname, state_atrname_end, state_atrvalue_begin, state_atrvalue, action_lt, action_gt, action_space, action_equal, action_quote, action_slash, action_chr, action_error, name_text, name_open, name_close, name_atrname, name_atrvalue, name_noop, name_solitary, name_extraneous, name_missingbracket, create};

}).call(this);

//# sourceMappingURL=main.js.map
