module tl_file.user.parser;

import std.algorithm;
import std.ascii: isDigit, isWhite;
import std.range: empty;
import std.utf: byCodeUnit;

import tl_file.common_parser;
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

string _stripLeft(string s) @nogc {
    return s.byCodeUnit().stripLeft!isWhite().source;
}

bool _isLocation(const(char)[ ] line) @nogc {
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
    string lang, id;

    bool opCast(B: bool)() const nothrow pure @nogc {
        return !lang.empty;
    }
}

_BlockHeaderData _parseBlockHeader(string line) @nogc {
    // ^translate\s+(\w+)\s+(\w+)\s*:
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
    if (lang.empty || id.empty || !s.stripLeft!isWhite().startsWith(':'))
        return _BlockHeaderData.init;
    return _BlockHeaderData(lang, id);
}

enum _BlockHeader: ubyte {
    none,
    dialogue,
    strings,
}

_BlockHeader _parseBlockHeader(string line, const(char)[ ] lang) @nogc {
    if (const h = _parseBlockHeader(line))
        if (h.lang == lang) {
            if (isDialogueID(h.id))
                return _BlockHeader.dialogue;
            else if (h.id == "strings")
                return _BlockHeader.strings;
        }
    return _BlockHeader.none;
}

struct _Expander {
nothrow pure @nogc:
    private {
        version (assert) string _data;
        string _cur;
    }

    this(string data) {
        version (assert) _data = data;
    }

    void reset() { _cur = null; }

    @property string get() const { return _cur; }

    void expandTo(string s) @trusted
    in {
        assert(s.ptr >= _data.ptr && s.ptr + s.length <= _data.ptr + _data.length);
    }
    do {
        if (_cur.empty)
            _cur = s;
        else {
            assert(s.ptr >= _cur.ptr);
            _cur = _cur.ptr[0 .. s.ptr - _cur.ptr + s.length];
        }
    }
}

public Declarations parse(string source, const(char)[ ] lang) {
    import std.array: appender;
    import std.string: lineSplitter;

    auto fileSummary = _Expander(source);
    auto blocks = appender!(Block[ ]);
    auto plainStrings = appender!(PlainString[ ]);

    auto state = _State.fileSummary;
    auto summary = _Expander(source);
    auto acc0 = _Expander(source);
    auto acc1 = _Expander(source);
    string oldText;
    foreach (line; source.lineSplitter())
        theSwitch: final switch (state) {
            case _State.fileSummary: {
                if (_isLocation(line)) {
                    state = _State.afterLocation;
                    break;
                } else
                    final switch (_parseBlockHeader(line, lang)) with (_BlockHeader) {
                        case none: break;
                        case dialogue: state = _State.dialogueBlock0; break theSwitch;
                        case strings:  state = _State.plainString0;   break theSwitch;
                    }
                fileSummary.expandTo(line);
                break;
            }

            case _State.afterLocation: {
                final switch (_parseBlockHeader(line, lang)) with (_BlockHeader) {
                case none: break;
                case dialogue:
                    state = _State.dialogueBlock0;
                    break theSwitch;
                case strings:
                    state = _State.plainString0;
                    acc0 = summary;
                    summary.reset();
                    break theSwitch;
                }
                summary.expandTo(line);
                if (!_isBlankLine(line)) {
                    state = _State.unrecognizedBlock;
                    acc0 = summary;
                    summary.reset();
                }
                break;
            }

            case _State.dialogueBlock0: {
                if (const old = extractDialogueOldText(line._stripLeft())) {
                    oldText = old;
                    state = _State.dialogueBlock1;
                    break;
                }
                // TODO: Unrecognized data handling.
                acc0.expandTo(line);
                break;
            }

            case _State.dialogueBlock1: {
                if (_isLocation(line))
                    state = _State.afterLocation;
                else
                    final switch (_parseBlockHeader(line, lang)) with (_BlockHeader) {
                    case none:
                        // TODO: Unrecognized data handling.
                        acc1.expandTo(line);
                        break theSwitch;
                    case dialogue:
                        state = _State.dialogueBlock0;
                        break;
                    case strings:
                        state = _State.plainString0;
                        break;
                    }
                blocks ~= Block(DialogueBlock(summary.get, acc0.get, oldText, acc1.get));
                summary.reset();
                acc0.reset();
                acc1.reset();
                oldText = null;
                break;
            }

            case _State.plainString0: {
                const s = line._stripLeft();
                if (_isLocation(s))
                    state = _State.plainString1;
                else if (const old = extractPlainStringOldText(s)) {
                    oldText = old;
                    state = _State.plainString2;
                } else {
                    acc0.expandTo(line);
                    break;
                }
                if (!acc0.get.byCodeUnit().all!isWhite()) {
                    blocks ~= Block(UnrecognizedBlock(acc0.get));
                    acc0.reset();
                }
                break;
            }

            case _State.plainString1: {
                if (const old = extractPlainStringOldText(line._stripLeft())) {
                    oldText = old;
                    state = _State.plainString2;
                    break;
                }
                acc0.expandTo(line);
                break;
            }

            case _State.plainString2: {
                const s = line._stripLeft();
                if (_isLocation(s))
                    state = _State.plainString1;
                else if (const old = extractPlainStringOldText(s))
                    oldText = old;
                else {
                    acc1.expandTo(line);
                    break;
                }
                plainStrings ~= PlainString(acc0.get, oldText, acc1.get);
                acc0.reset();
                acc1.reset();
                oldText = null;
                break;
            }

            case _State.unrecognizedBlock: {
                assert(false, "Unrecognized syntax in the translation file");
            }
        }

    return Declarations(fileSummary.get, blocks.data, plainStrings.data);
}
