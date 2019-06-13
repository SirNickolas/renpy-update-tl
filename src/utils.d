@safe:

bool isCIdent(const(char)[ ] name) nothrow pure @nogc {
    import std.algorithm.searching;
    import std.ascii;
    import std.range;
    import std.utf;

    return
        !name.empty &&
        (isAlpha(name[0]) || name[0] == '_') &&
        name[1 .. $].byChar().all!(c => isAlphaNum(c) || c == '_');
}
