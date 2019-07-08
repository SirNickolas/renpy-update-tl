module tl_file.common_parser;

import std.algorithm;
import std.ascii: isWhite;
import std.utf: byCodeUnit;

import utils: isCIdent;

private nothrow pure @safe @nogc:

bool _isDialogueID(const(char)[ ] id) {
    import std.ascii: isHexDigit;

    // ^[A-Za-z0-9_]+_[A-Fa-f0-9]{8,16}$
    auto s = id.byCodeUnit();
    auto t = s.stripRight!isHexDigit();
    if (s.length - t.length < 8 || s.length - t.length > 16)
        return false;
    return t.length > 1 && t.endsWith('_') && t[0 .. $ - 1].all!isCIdent();
}

package bool isDialogueID(const(char)[ ] id) {
    import std.ascii: isDigit;

    // ^[A-Za-z0-9_]+_[A-Fa-f0-9]{8,16}(?:_\d*)?$
    if (_isDialogueID(id))
        return true;
    auto s = id.byCodeUnit().stripRight!isDigit();
    return s.endsWith('_') && _isDialogueID(s.source[0 .. $ - 1]);
}

const(char)[ ] _extractDialogueOldText(return const(char)[ ] line) {
    // ^#\s*((?:\w*\s*"|nvl\b).*?)\s*$
    auto s = line.byCodeUnit();
    if (!s.skipOver('#'))
        return null;
    s.skipOver!isWhite();
    if (!s.stripLeft!isCIdent().stripLeft!isWhite().startsWith('"')) {
        auto t = s;
        if (!t.skipOver("nvl".byCodeUnit()) || t.startsWith!isCIdent())
            return null;
    }
    return s.stripRight!isWhite().source;
}

const(char)[ ] _extractPlainStringOldText(return const(char)[ ] line) {
    // ^old\s*(".*?)\s*$
    auto s = line.byCodeUnit();
    if (!s.skipOver("old".byCodeUnit()))
        return null;
    s.skipOver!isWhite();
    if (!s.startsWith('"'))
        return null;
    return s.stripRight!isWhite().source;
}

// Cannot use `inout` in the functions above, so manually cast `const` away.
package S extractDialogueOldText(S: const(char)[ ] = const(char)[ ])(S line) @trusted {
    return cast(S)_extractDialogueOldText(line);
}

package S extractPlainStringOldText(S: const(char)[ ] = const(char)[ ])(S line) @trusted {
    return cast(S)_extractPlainStringOldText(line);
}
