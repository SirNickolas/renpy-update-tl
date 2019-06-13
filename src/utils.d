module utils;

import std.range;

bool skipOver1(alias pred, R)(ref R r) if (isInputRange!R) {
    import std.functional;

    if (r.empty || !unaryFun!pred(r.front))
        return false;
    r.popFront();
    return true;
}

@safe:

bool isCIdent(dchar c) nothrow pure @nogc {
    import std.ascii;

    return isAlphaNum(c) || c == '_';
}

bool isValidCIdent(const(char)[ ] name) nothrow pure @nogc {
    import std.algorithm.searching;
    import std.ascii;
    import std.utf;

    auto s = name.byChar();
    return s.skipOver1!(c => isAlpha(c) || c == '_') && s.all!isCIdent();
}
