module tl_file.user.parser;

import std.algorithm;
import std.ascii: isWhite;
import std.range.primitives: empty;
import std.utf: byCodeUnit;

import tl_file.user.model;

import utils: isCIdent;

private nothrow pure @safe:

bool _isLocation(const(char)[ ] line) @nogc {
    import std.ascii: isDigit;

    // ^#\s*[^\0-\x1F?*<>|:]*\.rpym?:\d+\s*$
    auto s = line.byCodeUnit();
    if (!s.skipOver('#'))
        return false;
    line = s.stripLeft!isWhite().source;
    foreach (i, c; line) {
        if (c.among!('?', '*', '<', '>', '|') || c < ' ')
            return false;
        if (c == ':') {
            if (!line[0 .. i].byCodeUnit().endsWith(".rpy".byCodeUnit(), ".rpym".byCodeUnit()))
                return false;
            s = line[i + 1 .. $].byCodeUnit().stripRight!isWhite();
            return !s.empty && s.all!isDigit();
        }
    }
    return false;
}

bool _isBlankLine(const(char)[ ] line) @nogc {
    // ^\s*(?:#|$)
    const s = line.byCodeUnit().stripLeft!isWhite();
    return s.empty || s[0] == '#';
}

struct _BlockHeaderData {
    string lang, id, rest;

    bool opCast(B: bool)() const nothrow pure @nogc {
        return !lang.empty;
    }
}

_BlockHeaderData _parseBlockHeader(string line) @nogc {
    // ^translate\s+(\w+)\s+(\w+)\s*:\s*(.*)
    _BlockHeaderData h;
    auto s = line.byCodeUnit();
    if (!s.skipOver("translate".byCodeUnit()))
        return _BlockHeaderData.init;
    auto t = s.stripLeft!isWhite();
    if (s.length == t.length)
        return _BlockHeaderData.init;
    s = t.stripLeft!isCIdent();
    const lang = t.source[0 .. $ - s.length];
    t = s.stripLeft!isWhite();
    s = t.stripLeft!isCIdent();
    const id = t.source[0 .. $ - s.length];
    if (lang.empty || id.empty)
        return _BlockHeaderData.init;
    s.skipOver!isWhite();
    if (!s.skipOver(':'))
        return _BlockHeaderData.init;
    return _BlockHeaderData(lang, id, s.stripLeft!isWhite().source);
}

bool _isSomeBlockHeader(const(char)[ ] line) @nogc {
    import std.ascii: isAlpha;

    // ^[A-Za-z].*?:\s*(?:#|$)
    auto s = line.byCodeUnit();
    if (!s.skipOver!isAlpha())
        return false;
    while (s.findSkip!q{a != ':'}) {
        s.popFront();
        s.skipOver!isWhite();
        if (s.empty || s[0] == '#')
            return true;
    }
    return false;
}

// Cannot use `SumType` because we need low-level control statements -
// namely, `goto case` and `break outerSwitch`.
struct _Line {
    enum Type: ubyte {
        other, // No data.
        location, // No data.
        dialogueBlockHeader, // `rest` and `id`.
        stringsBlockHeader, // `rest`.
        unrecognizedBlockHeader, // No data.
        dialogueOld, // `oldText`.
        plainStringOld, // `oldText`.
    }

    Type type;
    string value0;
    string value1;
}

enum _LineDesc {
    // Variants:
    location,
    dialogueOld,
    plainStringOld,
    blockHeader,
    // Modifiers (make sure they don't clash with variants):
    indented = 0x4,
    noModifiers = ~indented,
}

enum _isLineDescIndented(_LineDesc t) = !!(t & _LineDesc.indented);
enum _removeLineDescModifiers(_LineDesc t) = t & _LineDesc.noModifiers;

_Line _parseLine(descriptors...)(string line, const(char)[ ] lang) @nogc {
    import std.meta;
    import tl_file.common_parser;

    static if (anySatisfy!(_isLineDescIndented, descriptors))
        const dedented = line.byCodeUnit().stripLeft!isWhite().source;
    static foreach (i, desc; staticMap!(_removeLineDescModifiers, descriptors)) {{
        static if (_isLineDescIndented!(descriptors[i]))
            alias s = dedented;
        else
            alias s = line;

        static if (desc == _LineDesc.location) {
            if (_isLocation(s))
                return _Line(_Line.Type.location);
        } else static if (desc == _LineDesc.dialogueOld) {
            if (const old = extractDialogueOldText(s))
                return _Line(_Line.Type.dialogueOld, old);
        } else static if (desc == _LineDesc.plainStringOld) {
            if (const old = extractPlainStringOldText(s))
                return _Line(_Line.Type.plainStringOld, old);
        } else static if (desc == _LineDesc.blockHeader) {
            if (const h = _parseBlockHeader(s)) {
                if (h.lang == lang) {
                    if (isDialogueID(h.id))
                        return _Line(_Line.Type.dialogueBlockHeader, h.rest, h.id);
                    else if (h.id == "strings")
                        return _Line(_Line.Type.stringsBlockHeader, h.rest);
                }
                return _Line(_Line.Type.unrecognizedBlockHeader);
            }
            if (_isSomeBlockHeader(s))
                return _Line(_Line.Type.unrecognizedBlockHeader);
        } else {
            import std.conv;

            static assert(false, text("Unknown line descriptor: ", int(descriptors[i])));
        }
    }}
    return _Line.init;
}

_Line _parseLine(string descriptors)(string line, const(char)[ ] lang) @nogc {
    with (_LineDesc)
        return mixin(`_parseLine!(` ~ descriptors ~ `)(line, lang)`);
}

public Declarations parse(string source, const(char)[ ] lang) {
    import std.array: appender;
    import std.string: lineSplitter;

    import slice_expander: expander;
    import tl_file.user.builder;

    auto blocks = appender!(Block[ ]);
    auto plainStrings = appender!(PlainString[ ]);
    auto lines = source.lineSplitter();
    auto fileSummary = expander(source);

summaryLoop:
    while (!lines.empty) {
        const line = lines.front;
        switch (_parseLine!q{location, blockHeader}(line, lang).type) with (_Line.Type) {
        case location, dialogueBlockHeader, stringsBlockHeader:
            break summaryLoop;
        case unrecognizedBlockHeader, other:
            fileSummary.expandTo(line);
            lines.popFront();
            continue;
        default:
            assert(false);
        }
    }

    auto unrecognized = expander(source);
    _Line ln;
theLoop:
    while (true) {
        // `unrecognized` may already be set; expand it further.
    unrecognizedLoop:
        while (!lines.empty) {
            const line = lines.front;
            ln = _parseLine!q{location, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case location, dialogueBlockHeader, stringsBlockHeader:
                break unrecognizedLoop;
            case unrecognizedBlockHeader, other:
                unrecognized.expandTo(line);
                lines.popFront();
                continue;
            default:
                assert(false);
            }
        }
        if (!unrecognized.get.byCodeUnit().all!isWhite())
            blocks ~= makeUnrecognizedBlock(unrecognized.get);
        unrecognized.reset();
        if (lines.empty)
            break theLoop;

        const blockStart = lines.front;
        auto summary = expander(source);
        switch (ln.type) {
            case _Line.Type.location: {
                lines.popFront();
                // Block summary (comments after location).
                while (true) {
                    if (lines.empty) {
                        unrecognized.reset(blockStart);
                        unrecognized.expandTo(summary.get);
                        continue theLoop;
                    }
                    const line = lines.front;
                    if (!_isBlankLine(line))
                        break;
                    summary.expandTo(line);
                    lines.popFront();
                }
                // Dialogue block header.
                ln = _parseLine!q{blockHeader}(lines.front, lang);
                if (ln.type != _Line.Type.dialogueBlockHeader) {
                    unrecognized.reset(blockStart);
                    unrecognized.expandTo(summary.get);
                    continue theLoop;
                }
                goto case;
            }
            case _Line.Type.dialogueBlockHeader: {
                const labelAndHash = ln.value1;
                string contents0LastLine = lines.front;
                lines.popFront();

                auto contents0 = expander(source);
            dialogueContents0Loop:
                while (true) {
                    if (lines.empty) {
                        unrecognized.reset(blockStart);
                        unrecognized.expandTo(contents0LastLine);
                        continue theLoop;
                    }
                    const line = contents0LastLine = lines.front;
                    ln = _parseLine!q{indented|dialogueOld, location, blockHeader}(line, lang);
                    switch (ln.type) with (_Line.Type) {
                    case dialogueOld:
                        break dialogueContents0Loop;
                    case other:
                        break;
                    case dialogueBlockHeader, stringsBlockHeader, unrecognizedBlockHeader:
                        unrecognized.reset(blockStart);
                        unrecognized.expandTo(contents0LastLine);
                        continue theLoop;
                    default:
                        assert(false);
                    }
                    contents0.expandTo(line);
                    lines.popFront();
                }
                const oldText = ln.value0;

                auto contents1 = expander(source);
                while (true) {
                    lines.popFront();
                    if (lines.empty)
                        break;
                    const line = lines.front;
                    ln = _parseLine!q{location, blockHeader}(line, lang);
                    if (ln.type != _Line.Type.other)
                        break;
                    contents1.expandTo(line);
                }

                blocks ~= makeDialogueBlock(
                    summary.get,
                    labelAndHash,
                    contents0.get,
                    oldText,
                    contents1.get,
                );
                continue theLoop;
            }

            case _Line.Type.stringsBlockHeader: {
                lines.popFront();
                // Blank lines between the block header and the first location.
                while (true) {
                    if (lines.empty) {
                        unrecognized.reset(blockStart);
                        continue theLoop;
                    }
                    if (!lines.front.byCodeUnit().all!isWhite())
                        break;
                    lines.popFront();
                }

                do {
                    string line = lines.front;
                    const pairStart = line;
                    if (_parseLine!q{indented|location}(line, lang).type == _Line.Type.location) {
                        if (!isWhite(line[0]))
                            continue theLoop;
                        lines.popFront();
                        if (lines.empty)
                            continue theLoop;
                        line = lines.front;
                    }

                    auto contents0 = expander(source);
                plainStringContents0Loop:
                    while (true) {
                        ln = _parseLine!q{indented|plainStringOld, location, blockHeader}(
                            line, lang,
                        );
                        switch (ln.type) with (_Line.Type) {
                        case plainStringOld:
                            break plainStringContents0Loop;
                        case other:
                            break;
                        case location:
                        case dialogueBlockHeader, stringsBlockHeader, unrecognizedBlockHeader:
                            if (!contents0.get.empty) {
                                unrecognized.reset(pairStart);
                                unrecognized.expandTo(contents0.get);
                            }
                            continue theLoop;
                        default:
                            assert(false);
                        }
                        contents0.expandTo(line);
                        lines.popFront();
                        if (lines.empty) {
                            unrecognized.reset(pairStart);
                            unrecognized.expandTo(contents0.get);
                            continue theLoop;
                        }
                        line = lines.front;
                    }
                    const oldText = ln.value0;

                    auto contents1 = expander(source);
                plainStringContents1Loop:
                    while (true) {
                        lines.popFront();
                        if (lines.empty)
                            break plainStringContents1Loop;
                        line = lines.front;
                        ln = _parseLine!q{indented|location, indented|plainStringOld, blockHeader}(
                            line, lang,
                        );
                        switch (ln.type) with (_Line.Type) {
                        case location, plainStringOld:
                        case dialogueBlockHeader, stringsBlockHeader, unrecognizedBlockHeader:
                            break plainStringContents1Loop;
                        case other:
                            break;
                        default:
                            assert(false);
                        }
                        contents1.expandTo(line);
                    }

                    plainStrings ~= makePlainString(contents0.get, oldText, contents1.get);
                } while (!lines.empty);
                continue theLoop;
            }

            default: assert(false);
        }
        assert(false);
    }

    return Declarations(fileSummary.get.stripBlankLines(), blocks.data, plainStrings.data);
}
