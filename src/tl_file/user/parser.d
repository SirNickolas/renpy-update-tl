module tl_file.user.parser;

import std.algorithm;
import std.ascii: isWhite;
import std.range: empty;
import std.utf: byCodeUnit;

import tl_file.user.model;

import utils: isCIdent;

private nothrow pure @safe:

enum _State: ubyte {
    fileSummary,
    afterLocation,
    dialogueBlock0, // Before old text.
    dialogueBlock1, // After old text.
    plainString0, // After the header.
    plainString1, // After location, before old text.
    plainString2, // After old text.
    unrecognizedBlock,
}

bool _isLocation(const(char)[ ] line) @nogc {
    import std.ascii: isDigit;

    // ^#[^\0-\x1F?*<>|:]*\.rpym?:\d+\s*$
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
    auto fileSummary = expander(source);
    auto summary = expander(source);
    auto acc0 = expander(source);
    auto acc1 = expander(source);
    auto lastBlock = expander(source);
    auto lastPlainString = expander(source);
    string labelAndHash, oldText;

    auto state = _State.fileSummary;
    _Line ln;
    foreach (line; source.lineSplitter())
        theSwitch: final switch (state) {
        case _State.fileSummary: // At the very beginning of the file.
            ln = _parseLine!q{location, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case location: // -> afterLocation
                state = _State.afterLocation;
                break;
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                labelAndHash = ln.value1;
                break;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                break;
            case unrecognizedBlockHeader: // Included in the file summary.
            case other:
                fileSummary.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            lastBlock.reset(line);
            break theSwitch;

        case _State.afterLocation:
            ln = _parseLine!q{blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                labelAndHash = ln.value1;
                break theSwitch;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                acc0 = summary;
                summary.reset();
                break theSwitch;
            case unrecognizedBlockHeader:
            case other:
                break;
            default:
                assert(false);
            }

            summary.expandTo(line);
            if (!_isBlankLine(line)) {
                // -> unrecognizedBlock
                state = _State.unrecognizedBlock;
                acc0 = summary;
                acc0.expandTo(line);
                summary.reset();
            }
            break theSwitch;

        case _State.dialogueBlock0: // After the header, before old text.
            ln = _parseLine!q{indented|dialogueOld, location, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case dialogueOld: // -> dialogueBlock1
                oldText = ln.value0;
                state = _State.dialogueBlock1;
                break theSwitch;
            case location: // -> afterLocation
                state = _State.afterLocation;
                break;
            case dialogueBlockHeader:
                labelAndHash = ln.value1;
                break;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                break;
            case unrecognizedBlockHeader: // -> unrecognizedBlock
                state = _State.unrecognizedBlock;
                goto case;
            case other:
                acc0.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            if (!acc0.get.byCodeUnit().all!isWhite()) {
                assert(!lastBlock.get.empty);
                lastBlock.expandTo(acc0.get);
                blocks ~= makeUnrecognizedBlock(lastBlock.get);
            }
            acc0.reset();
            lastBlock.reset(line);
            break theSwitch;

        case _State.dialogueBlock1: // After old text.
            ln = _parseLine!q{location, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case location: // -> afterLocation
                state = _State.afterLocation;
                break;
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                break;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                break;
            case unrecognizedBlockHeader: // -> unrecognizedBlock
                state = _State.unrecognizedBlock;
                break;
            case other:
                acc1.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            blocks ~= makeDialogueBlock(summary.get, labelAndHash, acc0.get, oldText, acc1.get);
            summary.reset();
            if (ln.type == _Line.Type.unrecognizedBlockHeader)
                acc0.reset(line);
            else {
                acc0.reset();
                lastBlock.reset(line);
                if (ln.type == _Line.Type.dialogueBlockHeader)
                    labelAndHash = ln.value1;
            }
            acc1.reset();
            oldText = null;
            break theSwitch;

        case _State.plainString0: // After the header, before location.
            ln = _parseLine!q{indented|location, indented|plainStringOld, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case location: // -> plainString1
                state = _State.plainString1;
                break;
            case plainStringOld: // -> plainString2
                oldText = ln.value0;
                state = _State.plainString2;
                break;
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                labelAndHash = ln.value1;
                break;
            case stringsBlockHeader:
                break;
            case unrecognizedBlockHeader: // -> unrecognizedBlock
                state = _State.unrecognizedBlock;
                assert(!lastBlock.get.empty);
                acc0 = lastBlock;
                goto case;
            case other:
                acc0.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            if (!acc0.get.byCodeUnit().all!isWhite())
                blocks ~= makeUnrecognizedBlock(acc0.get);
            acc0.reset();
            lastPlainString.reset(line);
            break theSwitch;

        case _State.plainString1: // After location, before old text.
            ln = _parseLine!q{indented|plainStringOld, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case plainStringOld: // -> plainString2
                oldText = ln.value0;
                state = _State.plainString2;
                break theSwitch;
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                labelAndHash = ln.value1;
                break;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                break;
            case unrecognizedBlockHeader: // -> unrecognizedBlock
                state = _State.unrecognizedBlock;
                goto case;
            case other:
                acc0.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            if (!acc0.get.byCodeUnit().all!isWhite())
                blocks ~= makeUnrecognizedBlock(acc0.get);
            acc0.reset();
            break theSwitch;

        case _State.plainString2: // After old text.
            ln = _parseLine!q{indented|location, indented|plainStringOld, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case location: // -> plainString1 | afterLocation
                state = isWhite(line[0]) ? _State.plainString1 : _State.afterLocation;
                break;
            case plainStringOld:
                break;
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                labelAndHash = ln.value1;
                break;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                break;
            case unrecognizedBlockHeader: // -> unrecognizedBlock
                state = _State.unrecognizedBlock;
                break;
            case other:
                acc1.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            plainStrings ~= makePlainString(acc0.get, oldText, acc1.get);
            acc0.reset();
            acc1.reset();
            if (ln.type == _Line.Type.plainStringOld)
                oldText = ln.value0;
            else {
                oldText = null;
                if (ln.type == _Line.Type.unrecognizedBlockHeader)
                    acc0.expandTo(line);
            }
            lastPlainString.reset(line);
            break theSwitch;

        case _State.unrecognizedBlock:
            ln = _parseLine!q{location, blockHeader}(line, lang);
            switch (ln.type) with (_Line.Type) {
            case location: // -> afterLocation
                state = _State.afterLocation;
                break;
            case dialogueBlockHeader: // -> dialogueBlock0
                state = _State.dialogueBlock0;
                labelAndHash = ln.value1;
                break;
            case stringsBlockHeader: // -> plainString0
                state = _State.plainString0;
                break;
            case unrecognizedBlockHeader:
            case other:
                acc0.expandTo(line);
                break theSwitch;
            default:
                assert(false);
            }

            blocks ~= makeUnrecognizedBlock(acc0.get);
            acc0.reset();
            break theSwitch;
        }

    final switch (state) with (_State) {
    case fileSummary:
        break;

    case afterLocation:
    case dialogueBlock0:
    case plainString0:
        blocks ~= makeUnrecognizedBlock(lastBlock.get);
        break;

    case dialogueBlock1:
        blocks ~= makeDialogueBlock(summary.get, labelAndHash, acc0.get, oldText, acc1.get);
        break;

    case plainString1:
        blocks ~= makeUnrecognizedBlock(lastPlainString.get);
        break;

    case plainString2:
        plainStrings ~= makePlainString(acc0.get, oldText, acc1.get);
        break;

    case unrecognizedBlock:
        blocks ~= makeUnrecognizedBlock(acc0.get);
        break;
    }

    return Declarations(fileSummary.get.stripBlankLines(), blocks.data, plainStrings.data);
}
