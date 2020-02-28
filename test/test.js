'use strict';
const test = require('ava');
const Lexer = require('../lib/main.js');
const Type = Lexer.Type;

const assert = (t, lexer, xml, expected) => {
    let idx = 0;
    lexer.on('data', d => {
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
        {type: Type.openTag, value: 'test'},
        {type: Type.text, value: 'text'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('happy case chunked', t => {
    const lexer = Lexer.create();
    const xml = `<test>text</test>`.split('');
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.text, value: 'text'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('single attribute without quotes', t => {
    const lexer = Lexer.create();
    const xml = `<test a=1></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '1'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('spaces around', t => {
    const lexer = Lexer.create();
    const xml = `<  test  foo  =  "bar baz"  >text< / test >`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'foo'},
        {type: Type.atr_value, value: 'bar baz'},
        {type: Type.text, value: 'text'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('slash breaking attribute', t => {
    const lexer = Lexer.create();
    const xml = `<test foo/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'foo'},
        {type: Type.atr_value, value: ''},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('tag closing before attribute value', t => {
    const lexer = Lexer.create();
    const xml = `<test foo ></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'foo'},
        {type: Type.atr_value, value: ''},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('tag closing before attribute value (with equal)', t => {
    const lexer = Lexer.create();
    const xml = `<test foo=></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'foo'},
        {type: Type.atr_value, value: ''},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('various attributes (single, double, no quotes, no value)', t => {
    const lexer = Lexer.create();
    const xml = `<test a=0 b='1' c="2" d></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '0'},
        {type: Type.atr_name, value: 'b'},
        {type: Type.atr_value, value: '1'},
        {type: Type.atr_name, value: 'c'},
        {type: Type.atr_value, value: '2'},
        {type: Type.atr_name, value: 'd'},
        {type: Type.atr_value, value: ''},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('various attributes without spaces', t => {
    const lexer = Lexer.create();
    const xml = `<test a='1'b="2"c></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '1'},
        {type: Type.atr_name, value: 'b'},
        {type: Type.atr_value, value: '2'},
        {type: Type.atr_name, value: 'c'},
        {type: Type.atr_value, value: ''},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('self closing tag', t => {
    const lexer = Lexer.create();
    const xml = `<test/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('self closing tag with slash after attribute value', t => {
    const lexer = Lexer.create();
    const xml = `<test a=1/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '1'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('slashes in attribute values', t => {
    const lexer = Lexer.create();
    const xml = `<test a='/'b="/"/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '/'},
        {type: Type.atr_name, value: 'b'},
        {type: Type.atr_value, value: '/'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('quotes inside quotes', t => {
    const lexer = Lexer.create();
    const xml = `<test a='"'b="'"/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '"'},
        {type: Type.atr_name, value: 'b'},
        {type: Type.atr_value, value: "'"},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('gt in attribute values', t => {
    const lexer = Lexer.create();
    const xml = `<test a='>'b=">"/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '>'},
        {type: Type.atr_name, value: 'b'},
        {type: Type.atr_value, value: '>'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('lt in attribute values', t => {
    const lexer = Lexer.create();
    const xml = `<test a='<'b="<"/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.atr_name, value: 'a'},
        {type: Type.atr_value, value: '<'},
        {type: Type.atr_name, value: 'b'},
        {type: Type.atr_value, value: '<'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('attributes are ignored after slash in self closing tag', t => {
    const lexer = Lexer.create();
    const xml = `<test/ a=0>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('attributes are ignored in closing tag', t => {
    const lexer = Lexer.create();
    const xml = `<test></test a=0>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('ignore tags starting with ?', t => {
    const lexer = Lexer.create();
    const xml = `<?xml foo=bar><test/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('ignore comments', t => {
    const lexer = Lexer.create();
    const xml = `<test><!-- comment --></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('read CDATA', t => {
    const lexer = Lexer.create();
    const xml = `<test><![CDATA[foo<bar>&bsp;baz]]><![CDATA[]><![CDATA[foo]]]]></test>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.text, value: 'foo<bar>&bsp;baz'},
        {type: Type.text, value: ']><![CDATA[foo]]'},
        {type: Type.closeTag, value: 'test'},
    ];
    assert(t, lexer, xml, expected);
});

test.cb('ignore DOCTYPE', t => {
    const lexer = Lexer.create();
    const xml = `<!DOCTYPE foo><test/>`;
    const expected = [
        {type: Type.openTag, value: 'test'},
        {type: Type.closeTag, value: 'test'},
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
        {type: Type.openTag, value: 'document'},
        {type: Type.text, value: 'x\n            '},
        {type: Type.openTag, value: 'title'},
        {type: Type.atr_name, value: 'attr'},
        {type: Type.atr_value, value: ''},
        {type: Type.text, value: 'Test'},
        {type: Type.closeTag, value: 'title'},
        {type: Type.closeTag, value: 'document'},
    ];
    assert(t, lexer, xml, expected);
});
