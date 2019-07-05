module utils;

import std.range.primitives: empty, isInputRange;

bool skipOver1(alias pred, R)(ref R r) if (isInputRange!R) {
    import std.functional;

    if (r.empty || !unaryFun!pred(r.front))
        return false;
    r.popFront();
    return true;
}

nothrow pure @safe @nogc:

@property T unreachable(T = void)() {
    assert(false, "unreachable!" ~ T.stringof);
}

T unreachable(T = void)(const(char)[ ] msg) {
    assert(false, msg);
}

bool isCIdent(dchar c) {
    import std.ascii;

    return isAlphaNum(c) || c == '_';
}

bool isValidCIdent(const(char)[ ] name) {
    import std.algorithm.searching;
    import std.ascii;
    import std.utf;

    auto s = name.byCodeUnit();
    return s.skipOver1!(c => isAlpha(c) || c == '_') && s.all!isCIdent();
}
