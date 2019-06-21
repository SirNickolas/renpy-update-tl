module tl_file.user.builder;

import tl_file.user.model;

nothrow pure @safe @nogc:

string stripBlankLines(string text) {
    import std.algorithm;
    import std.ascii: isWhite;
    import std.range: empty;
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

private alias _strip = stripBlankLines;

Block makeDialogueBlock(
    string summary,
    string labelAndHash,
    string contents0,
    string oldText,
    string contents1,
) {
    return Block(DialogueBlock(
        summary._strip(),
        labelAndHash,
        contents0._strip(),
        oldText,
        contents1._strip(),
    ));
}

Block makeUnrecognizedBlock(string contents) {
    return Block(UnrecognizedBlock(contents._strip()));
}

PlainString makePlainString(string contents0, string oldText, string contents1) {
    return PlainString(contents0._strip(), oldText, contents1._strip());
}
