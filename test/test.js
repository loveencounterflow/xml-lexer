'use strict';
const test = require('ava');
const Lexer = require('../lib/main.js');
// const Type = Lexer.Type;

const assert = (t, lexer, xml, expected) => {
    let idx = 0;
    console.log( '^098^', '—————————————————————————————————————' );
    console.log( '^098^', JSON.stringify( xml ) );
    lexer.on('data', d => {
    		console.log( '^098^', JSON.stringify( d ) );
        t.deepEqual(d, expected[idx], JSON.stringify(d));
        if (++idx >= expected.length) t.end();
    });
    if (Array.isArray(xml)) {
        xml.forEach(chunk => lexer.write(chunk));
    } else {
        lexer.write(xml);
    }
};

test.cb('happy case', t => {
    const lexer = Lexer.create();
    const xml = `<test>text</test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_text, value: 'text'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('happy case chunked', t => {
    const lexer = Lexer.create();
    const xml = `<test>text</test>`.split('');
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_text, value: 'text'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('single attribute without quotes', t => {
    const lexer = Lexer.create();
    const xml = `<test a=1></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '1'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('spaces around', t => {
    const lexer = Lexer.create();
    const xml = `<  test  foo  =  "bar baz"  >text< / test >`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'foo'},
        {type: Lexer.name_atrvalue, value: 'bar baz'},
        {type: Lexer.name_text, value: 'text'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('slash breaking attribute', t => {
    const lexer = Lexer.create();
    const xml = `<test foo/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'foo'},
        {type: Lexer.name_atrvalue, value: ''},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('tag closing before attribute value', t => {
    const lexer = Lexer.create();
    const xml = `<test foo ></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'foo'},
        {type: Lexer.name_atrvalue, value: ''},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('tag closing before attribute value (with equal)', t => {
    const lexer = Lexer.create();
    const xml = `<test foo=></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'foo'},
        {type: Lexer.name_atrvalue, value: ''},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('various attributes (single, double, no quotes, no value)', t => {
    const lexer = Lexer.create();
    const xml = `<test a=0 b='1' c="2" d></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '0'},
        {type: Lexer.name_atrname, value: 'b'},
        {type: Lexer.name_atrvalue, value: '1'},
        {type: Lexer.name_atrname, value: 'c'},
        {type: Lexer.name_atrvalue, value: '2'},
        {type: Lexer.name_atrname, value: 'd'},
        {type: Lexer.name_atrvalue, value: ''},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('various attributes without spaces', t => {
    const lexer = Lexer.create();
    const xml = `<test a='1'b="2"c></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '1'},
        {type: Lexer.name_atrname, value: 'b'},
        {type: Lexer.name_atrvalue, value: '2'},
        {type: Lexer.name_atrname, value: 'c'},
        {type: Lexer.name_atrvalue, value: ''},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('self closing tag', t => {
    const lexer = Lexer.create();
    const xml = `<test/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('self closing tag with slash after attribute value', t => {
    const lexer = Lexer.create();
    const xml = `<test a=1/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '1'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('slashes in attribute values', t => {
    const lexer = Lexer.create();
    const xml = `<test a='/'b="/"/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '/'},
        {type: Lexer.name_atrname, value: 'b'},
        {type: Lexer.name_atrvalue, value: '/'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('quotes inside quotes', t => {
    const lexer = Lexer.create();
    const xml = `<test a='"'b="'"/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '"'},
        {type: Lexer.name_atrname, value: 'b'},
        {type: Lexer.name_atrvalue, value: "'"},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('gt in attribute values', t => {
    const lexer = Lexer.create();
    const xml = `<test a='>'b=">"/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '>'},
        {type: Lexer.name_atrname, value: 'b'},
        {type: Lexer.name_atrvalue, value: '>'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('lt in attribute values', t => {
    const lexer = Lexer.create();
    const xml = `<test a='<'b="<"/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_atrname, value: 'a'},
        {type: Lexer.name_atrvalue, value: '<'},
        {type: Lexer.name_atrname, value: 'b'},
        {type: Lexer.name_atrvalue, value: '<'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('attributes are ignored after slash in self closing tag', t => {
    const lexer = Lexer.create();
    const xml = `<test/ a=0>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('attributes are ignored in closing tag', t => {
    const lexer = Lexer.create();
    const xml = `<test></test a=0>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('ignore tags starting with ?', t => {
    const lexer = Lexer.create();
    const xml = `<?xml foo=bar><test/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('ignore comments', t => {
    const lexer = Lexer.create();
    const xml = `<test><!-- comment --></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('read CDATA', t => {
    const lexer = Lexer.create();
    const xml = `<test><![CDATA[foo<bar>&bsp;baz]]><![CDATA[]><![CDATA[foo]]]]></test>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_text, value: 'foo<bar>&bsp;baz'},
        {type: Lexer.name_text, value: ']><![CDATA[foo]]'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('ignore DOCTYPE', t => {
    const lexer = Lexer.create();
    const xml = `<!DOCTYPE foo><test/>`;
    const expected = [
        {type: Lexer.name_open, value: 'test'},
        {type: Lexer.name_close, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('issue #6', t => {
    const xml =
        `<document>x
            <title attr>Test</title>
        </document>`;
    const lexer = Lexer.create();
    const expected = [
        { type: Lexer.name_open,     	value: 'document'       	},
        { type: Lexer.name_text,     	value: 'x\n            '	},
        { type: Lexer.name_open,     	value: 'title'          	},
        { type: Lexer.name_atrname,  	value: 'attr'           	},
        { type: Lexer.name_atrvalue, 	value: ''               	},
        { type: Lexer.name_text,     	value: 'Test'           	},
        { type: Lexer.name_close,    	value: 'title'          	},
				{ type: Lexer.name_text,    	value: "\n        "     	},
        { type: Lexer.name_close,    	value: 'document'       	},
    ];
    assert(t, lexer, xml, expected);
});


