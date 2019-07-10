module tl_file.user.builder;

import tl_file.user.model;

nothrow pure @safe @nogc:

string stripBlankLines(string text) {
    import std.algorithm;
    import std.ascii: isWhite;
    import std.range.primitives: empty;
    import std.utf: byCodeUnit;

    auto s = text.byCodeUnit().stripRight!isWhite();
    if (s.empty)
        return null;
    while (true) {
        const t = s;
        while (s.front.among!(' ', '\t', '\v', '\f'))
            s.popFront();
        if (!s.front.among!('\n', '\r'))
            return t.source;
        do
            s.popFront();
        while (s.front.among!('\n', '\r'));
    }
}

private TranslationState _classifyBlock(string oldText, string newText) {
    import std.algorithm;
    import std.ascii: isWhite;
    import std.utf: byCodeUnit;

    auto s = newText.byCodeUnit().stripLeft!isWhite();
    if (s.source == oldText)
        return TranslationState.identical;
    auto t = s.find('"');
    if (t.length >= 2 && t[0] == t[1]) {
        auto old = oldText.byCodeUnit();
        if (old.startsWith(s[0 .. $ - (t.length - 1)]) && old.endsWith(t[1 .. $]))
            return TranslationState.blank;
    }
    return TranslationState.translated;
}

private TranslationState _classifyPlainString(string oldText, string newText) {
    import std.algorithm;
    import std.ascii: isWhite;
    import std.utf: byCodeUnit;

    auto s = newText.byCodeUnit().stripLeft!isWhite();
    if (s.skipOver("new".byCodeUnit())) {
        newText = s.stripLeft!isWhite().source;
        if (newText.among!(`""`, `''`))
            return TranslationState.blank;
        if (newText == oldText)
            return TranslationState.identical;
    }
    return TranslationState.translated;
}

private alias _strip = stripBlankLines;

Block makeDialogueBlock(
    string summary,
    string labelAndHash,
    string contents0,
    string oldVoice,
    string oldText,
    string contents1,
    string newVoice,
    string contents2,
) {
    contents2 = contents2._strip();
    return Block(DialogueBlock(
        summary._strip(),
        labelAndHash,
        contents0._strip(),
        oldVoice,
        oldText,
        contents1._strip(),
        newVoice,
        contents2,
        _classifyBlock(oldText, contents2),
    ));
}

Block makeUnrecognizedBlock(string contents) {
    return Block(UnrecognizedBlock(contents._strip()));
}

PlainString makePlainString(string contents0, string oldText, string contents1) {
    contents1 = contents1._strip();
    return PlainString(
        contents0._strip(),
        oldText,
        contents1,
        _classifyPlainString(oldText, contents1),
    );
}
