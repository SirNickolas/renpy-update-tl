module model.lang;

nothrow pure @safe @nogc:

bool isValidLangName(const(char)[ ] name) {
    import std.algorithm.searching: all;
    import std.ascii: isAlpha, isAlphaNum;
    import std.range: empty;
    import std.utf: byCodeUnit;

    if (name.empty || name == "None" || (!isAlpha(name[0]) && name[0] != '_'))
        return false;
    return name[1 .. $].byCodeUnit().all!(c => isAlphaNum(c) || c == '_');
}
