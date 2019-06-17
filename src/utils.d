module utils;

import std.range: empty, isInputRange;

@property T unreachable(T = void)() nothrow pure @safe @nogc {
    assert(false, "unreachable!" ~ T.stringof);
}

T unreachable(T = void)(const(char)[ ] msg) nothrow pure @safe @nogc {
    assert(false, msg);
}

// Workaround for `@nogc` problem with `sumtype.match` when passing a typed delegate
// that captures variables from an outer context.
// Example:
//     a.match!((int x) => s += x); // Allocates a closure.
//     a.match!(case_!(int, x => s += x)); // @nogc
template case_(T, alias f) {
    static if (__traits(compiles, f()))
        auto case_()(ref const T _) { return f(); }
    else static if (__traits(compiles, f(T.init)))
        auto case_()(ref const T x) { return f(x); }
    else
        auto case_()(ref T x) { return f(x); }
}

template case_(T) {
    void case_()(ref const T _) { }
}

bool skipOver1(alias pred, R)(ref R r) if (isInputRange!R) {
    import std.functional;

    if (r.empty || !unaryFun!pred(r.front))
        return false;
    r.popFront();
    return true;
}

nothrow pure @safe @nogc:

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
