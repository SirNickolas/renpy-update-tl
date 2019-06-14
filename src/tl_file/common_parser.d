module tl_file.common_parser;

import std.algorithm;
import std.ascii: isHexDigit, isWhite;
import std.utf: byChar;

import utils: isCIdent;

private nothrow pure @safe @nogc:

package bool isDialogueID(const(char)[ ] id) {
    // ^[A-Za-z0-9_]+_[A-Fa-f0-9]{8,16}$
    auto s = id.byChar();
    auto t = s.stripRight!isHexDigit();
    if (s.length - t.length < 8 || s.length - t.length > 16)
        return false;
    return t.length > 1 && t.endsWith('_') && t[0 .. $ - 1].all!isCIdent();
}

const(char)[ ] _extractDialogueOldText(return const(char)[ ] line) {
    // ^#\s*(\w*\s*".*?)\s*$
    auto s = line.byChar();
    if (!s.skipOver('#'))
        return null;
    s.skipOver!isWhite();
    auto t = s.stripLeft!isCIdent().stripLeft!isWhite();
    if (!t.startsWith('"'))
        return null;
    return s.stripRight!isWhite().source;
}

const(char)[ ] _extractPlainStringOldText(return const(char)[ ] line) {
    // ^old\s*(".*?)\s*$
    auto s = line.byChar();
    if (!s.skipOver("old".byChar()))
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
