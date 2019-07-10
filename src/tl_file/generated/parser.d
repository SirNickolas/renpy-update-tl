module tl_file.generated.parser;

import std.algorithm;
import std.ascii: isDigit, isWhite;
import std.utf: byCodeUnit;

import tl_file.common_parser;
import tl_file.generated.model;
import utils: isCIdent;

private nothrow pure @safe:

const(char)[ ] _extractLocation(const(char)[ ] line) @nogc {
    // ^#\s*(.*?\.rpym?:\d.*?)\s*$
    auto s = line.byCodeUnit();
    if (!s.skipOver('#'))
        return null;
    s.skipOver!isWhite();
    auto t = s.find(".rpy".byCodeUnit());
    if (t.empty)
        return null;
    t = t[4 .. $];
    t.skipOver('m');
    if (!t.skipOver(':') || !t.startsWith!isDigit())
        return null;
    return s.stripRight!isWhite().source;
}

const(char)[ ] _extractBlockID(const(char)[ ] line) @nogc {
    // ^translate\s+\w+\s+(\w+)\s*:
    auto s = line.byCodeUnit();
    if (!s.skipOver("translate".byCodeUnit()))
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

const(char)[ ] _extractDialogueNewText(const(char)[ ] line) @nogc {
    // ^((?:\w*\s*"|nvl\b).*?)\s*$
    auto s = line.byCodeUnit();
    if (!s.stripLeft!isCIdent().stripLeft!isWhite().startsWith('"')) {
        auto t = s;
        if (!t.skipOver("nvl".byCodeUnit()) || t.startsWith!isCIdent())
            return null;
    }
    return s.stripRight!isWhite().source;
}

public Declarations parse(const(char)[ ] source) {
    import std.array: appender;
    import std.range.primitives: empty;
    import std.string: lineSplitter;
    import string_interner;

    auto dialogueBlocks = appender!(DialogueBlock[ ]);
    auto plainStrings = appender!(PlainString[ ]);
    StringInterner interner;

    const(char)[ ] labelAndHash, location, oldVoice, oldText;
    bool parsingPlainStrings;
    foreach (line; source.lineSplitter()) {
        if (line.empty)
            continue;
        line = line.byCodeUnit().stripLeft(' ').source;
        if (const s = _extractLocation(line))
            location = s;
        else if (const s = _extractBlockID(line)) {
            parsingPlainStrings = s == "strings";
            if (!parsingPlainStrings && isDialogueID(s))
                labelAndHash = s;
        } else if (!parsingPlainStrings) {
            if (const s = extractDialogueOldText(line))
                if (isDialogueVoice(s))
                    oldVoice = s;
                else
                    oldText = s;
            else if (!labelAndHash.empty && (!oldVoice.empty || !oldText.empty))
                if (const newText = _extractDialogueNewText(line)) {
                    if (oldText.empty) {
                        // Voice without text.
                        oldText = oldVoice;
                        oldVoice = null;
                    } else if (isDialogueVoice(newText))
                        continue;
                    dialogueBlocks ~= DialogueBlock(
                        location.idup,
                        labelAndHash.idup,
                        oldVoice.idup,
                        oldText.idup,
                        interner.intern(newText),
                    );
                    location = oldVoice = oldText = null;
                }
        } else if (const s = extractPlainStringOldText(line)) {
            plainStrings ~= PlainString(location.idup, s.idup);
            location = oldVoice = oldText = null;
        }
    }

    return Declarations(dialogueBlocks.data, plainStrings.data);
}
