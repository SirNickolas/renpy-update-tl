module tl_file.generated.parser;

import std.algorithm;
import std.ascii: isDigit, isHexDigit, isWhite;
import std.utf: byChar;

import tl_file.generated.model;
import utils: isCIdent;

private nothrow pure @safe:

const(char)[ ] _extractLocation(const(char)[ ] line) @nogc {
    // ^#\s*(.*?\.rpym?:\d.*?)\s*$
    auto s = line.byChar();
    if (!s.skipOver('#'))
        return null;
    s.skipOver!isWhite();
    auto t = s.find(".rpy".byChar());
    t.skipOver('m');
    if (!t.skipOver(':') || !t.startsWith!isDigit())
        return null;
    return s.stripRight!isWhite().source;
}

const(char)[ ] _extractBlockID(const(char)[ ] line) @nogc {
    // ^translate\s+\w+\s+(\w+)\s*:
    auto s = line.byChar();
    if (!s.skipOver("translate".byChar()))
        return null;
    auto t = s.stripLeft!isWhite();
    if (s.length == t.length)
        return null;
    s = t.stripLeft!isCIdent().stripLeft!isWhite();
    t = s.stripLeft!isCIdent();
    const id = s.source[0 .. $ - t.length];
    t.skipOver!isWhite();
    return t.startsWith(':') ? id : null;
}

bool _isDialogueID(const(char)[ ] id) @nogc {
    // ^[A-Za-z0-9_]+_[A-Fa-f0-9]{8,16}$
    auto s = id.byChar();
    auto t = s.stripRight!isHexDigit();
    if (s.length - t.length < 8 || s.length - t.length > 16)
        return false;
    return t.length > 1 && t.endsWith('_') && t.all!isCIdent();
}

const(char)[ ] _extractDialogueOldText(const(char)[ ] line) @nogc {
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

const(char)[ ] _extractDialogueNewText(const(char)[ ] line) @nogc {
    // ^(\w*\s*".*?)\s*$
    auto s = line.byChar();
    if (!s.stripLeft!isCIdent().stripLeft!isWhite().startsWith('"'))
        return null;
    return s.stripRight!isWhite().source;
}

const(char)[ ] _extractPlainStringOldText(const(char)[ ] line) @nogc {
    // ^old\s*(".*?)\s*$
    auto s = line.byChar();
    if (!s.skipOver("old".byChar()))
        return null;
    s.skipOver!isWhite();
    if (!s.startsWith('"'))
        return null;
    return s.stripRight!isWhite().source;
}

public Declarations parse(const(char)[ ] source) {
    import std.array;
    import std.range;
    import std.string: lineSplitter;
    import string_interner;

    auto dialogueBlocks = appender!(DialogueBlock[ ]);
    auto plainStrings = appender!(PlainString[ ]);
    StringInterner interner;

    string labelAndHash;
    const(char)[ ] location, oldText;
    bool parsingPlainStrings;
    foreach (line; source.lineSplitter()) {
        if (line.empty)
            continue;
        line = line.byChar().stripLeft(' ').source;
        if (const s = _extractLocation(line))
            location = s;
        else if (const s = _extractBlockID(line)) {
            parsingPlainStrings = s == "strings";
            if (!parsingPlainStrings && _isDialogueID(s))
                labelAndHash = s.idup;
        } else if (!parsingPlainStrings) {
            if (const s = _extractDialogueOldText(line))
                oldText = s;
            else if (!labelAndHash.empty && !oldText.empty)
                if (const newText = _extractDialogueNewText(line)) {
                    dialogueBlocks ~= DialogueBlock(
                        location.idup, labelAndHash, oldText.idup, interner.intern(newText),
                    );
                    location = oldText = null;
                }
        } else if (const s = _extractPlainStringOldText(line)) {
            plainStrings ~= PlainString(location.idup, s.idup);
            location = oldText = null;
        }
    }

    return Declarations(dialogueBlocks.data, plainStrings.data);
}
