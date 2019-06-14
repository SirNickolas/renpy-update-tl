module tl_file.user.parser;

import std.algorithm;
import std.ascii: isDigit, isWhite;
import std.range: empty;
import std.utf: byChar;

import tl_file.common_parser;
import tl_file.user.model;

import utils: isCIdent;

private nothrow pure @safe:

enum _State: ubyte {
    fileSummary,
    dialogueBlock0, // Before the old text.
    dialogueBlock1, // After the old text.
    plainString0, // Before the old text.
    plainString1, // After the old text.
    unrecognizedBlock,
}

bool _isLocationLine(const(char)[ ] line) @nogc {
    // ^#[^\0-\x1F?*<>|:]*\.rpym?:\d+\s*$
    auto s = line.byChar();
    if (!s.skipOver('#'))
        return false;
    line = s.stripLeft!isWhite().source;
    foreach (i, c; line) {
        if (c.among!('?', '*', '<', '>', '|') || c < ' ')
            return false;
        if (c == ':') {
            if (!line[0 .. i].byChar().endsWith(".rpy".byChar(), ".rpym".byChar()))
                return false;
            s = line[i + 1 .. $].byChar().stripRight!isWhite();
            return !s.empty && s.all!isDigit();
        }
    }
    return false;
}

struct _TranslationBlockHeader {
    string lang, id, tail;

    bool opCast(B: bool)() const nothrow pure @nogc {
        return !lang.empty;
    }
}

_TranslationBlockHeader _parseTranslationBlockHeader(string line) @nogc {
    // ^translate\s+(\w+)\s+(\w+)\s*:\s*(.*)
    _TranslationBlockHeader h;
    auto s = line.byChar();
    if (!s.skipOver("translate".byChar()))
        return _TranslationBlockHeader.init;
    auto t = s.stripLeft!isWhite();
    if (s.length == t.length)
        return _TranslationBlockHeader.init;
    s = t.stripLeft!isCIdent();
    const lang = t.source[0 .. $ - s.length];
    t = s.stripLeft!isWhite();
    s = t.stripLeft!isCIdent();
    const id = t.source[0 .. $ - s.length];
    if (lang.empty || id.empty)
        return _TranslationBlockHeader.init;
    s.skipOver!isWhite();
    if (!s.skipOver(':'))
        return _TranslationBlockHeader.init;
    return _TranslationBlockHeader(lang, id, s.stripLeft!isWhite().source);
}

public Declarations parse(string source, const(char)[ ] lang) {
    import std.array: appender;
    import std.string: lineSplitter;

    string summary;
    auto blocks = appender!(Block[ ]);
    auto plainStrings = appender!(PlainString[ ]);

    return Declarations(summary, blocks.data, plainStrings.data);
}
