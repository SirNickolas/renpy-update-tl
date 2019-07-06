module ct_ini;

import std.meta: Filter, staticMap;

private pure @safe:

struct _Token {
    enum Type: ubyte { data, section, eof }

    Type type;
    string key; // Or a section name.
    string value;
}

struct _Lexer {
pure:
    size_t i;
    string s;
    char[ ] buffer;

    void skipWhitespace() nothrow @nogc {
        for (; i != s.length; i++) {
            const c = s[i];
            if (c != ' ' && c != '\t')
                return;
        }
    }

    string captureWord(char stop) nothrow @nogc {
        const start = i;
        for (; i != s.length; i++) {
            const c = s[i];
            if (c == ' ' || c == '\t' || c == stop)
                break;
        }
        return s[start .. i];
    }

    void put(size_t j, char c) nothrow {
        if (j == buffer.length)
            buffer.length <<= 1;
        buffer[j] = c;
    }

    uint interpretHexDigit(char c) {
        uint x = c - '0';
        if (x < 10u)
            return x;
        x = (c | 0x20) - 'a';
        if (x < 6u)
            return x + 10;
        throw new Exception("Invalid hex digit `" ~ c ~ '`');
    }

    string captureLine()
    out (result) {
        assert(result !is null);
    }
    do {
        import std.exception: enforce;
        import std.utf: byChar, isValidDchar;

        const start = i;
        size_t end = s.length;
        size_t j; // Index in `buffer`.
        size_t rawStart = start; // Index in `s`.
        uint hiWord, octal;
        dchar[1] uni;
        while (i != s.length) {
            char c = s[i++];
            if (c == '\n' || c == '\r') {
                end = i - 1;
                break;
            } else if (c != '\\')
                continue;

            // Found a backslash.
            if (const len = i - 1 - rawStart) {
                // Copy part of the string we've skipped over.
                if (j + len > buffer.length) {
                    if (j + len <= buffer.length << 1)
                        buffer.length <<= 1;
                    else
                        buffer.length = j + len + 16; // Rather arbitrary number.
                }
                buffer[j .. j + len] = s[rawStart .. i - 1];
                j += len;
            }

            // https://dlang.org/spec/lex.html#escape_sequences
            enforce(i != s.length, "Incomplete escape sequence: `\\`");
            const esc = i;
            c = s[i++];
            rawStart = i;
            switch (c) {
            case '\'', '"', '?', '\\':
                put(j++, c);
                continue;

            case 'a': put(j++, '\a'); break;
            case 'b': put(j++, '\b'); break;
            case 'f': put(j++, '\f'); break;
            case 'n': put(j++, '\n'); break;
            case 'r': put(j++, '\r'); break;
            case 't': put(j++, '\t'); break;
            case 'v': put(j++, '\v'); break;

            case '0': .. case '3':
                octal = c - '0';
                if (i != s.length) {
                    uint c1 = s[i] - '0';
                    if (c1 < 8u) {
                        octal = octal << 3 | c1;
                        if (i + 1 != s.length) {
                            c1 = s[i + 1] - '0';
                            if (c1 < 8u) {
                                octal = octal << 3 | c1;
                                i += 2;
                                goto setRawStartOctal;
                            }
                        }
                        i++;
                    setRawStartOctal:
                        rawStart = i;
                    }
                }
                put(j++, cast(char)octal);
                continue;

            case 'x':
                enforce(i + 2 <= s.length, "Incomplete escape sequence: `\\" ~ s[esc .. $] ~ '`');
                put(j++, cast(char)(
                    interpretHexDigit(s[i]) << 4 | interpretHexDigit(s[i + 1])
                ));
                rawStart = i += 2;
                continue;

            case 'u':
                enforce(i + 4 <= s.length, "Incomplete escape sequence: `\\" ~ s[esc .. $] ~ '`');
                if (j + 3 > buffer.length)
                    buffer.length <<= 1;
                hiWord = 0x0;
            takeUnicodeLoWord:
                uni[0] =
                    hiWord |
                    interpretHexDigit(s[i])     << 12 |
                    interpretHexDigit(s[i + 1]) << 8 |
                    interpretHexDigit(s[i + 2]) << 4 |
                    interpretHexDigit(s[i + 3]);
                rawStart = i += 4;
                enforce(isValidDchar(uni[0]), "Invalid Unicode character `\\" ~ s[esc .. i] ~ '`');
                foreach (c1; uni[ ].byChar())
                    buffer[j++] = c1;
                continue;

            case 'U':
                enforce(i + 8 <= s.length, "Incomplete escape sequence: `\\" ~ s[esc .. $] ~ '`');
                if (j + 4 > buffer.length)
                    buffer.length <<= 1;
                hiWord =
                    interpretHexDigit(s[i])     << 28 |
                    interpretHexDigit(s[i + 1]) << 24 |
                    interpretHexDigit(s[i + 2]) << 20 |
                    interpretHexDigit(s[i + 3]) << 16;
                i += 4;
                goto takeUnicodeLoWord;

            default:
                // Named character entities are not supported either.
                throw new Exception("Invalid escape sequence `\\" ~ c ~ '`');
            }
        }

        if (rawStart == start)
            return s[start .. end]; // No escape sequences - just return a slice of the input.
        if (const len = end - rawStart) {
            if (j + len > buffer.length)
                buffer.length = j + len;
            buffer[j .. j + len] = s[rawStart .. end];
            j += len;
        }
        return buffer[0 .. j].idup;
    }

    _Token getNext() {
        import std.exception: enforce;

        string capture;
        while (true) {
            skipWhitespace();
            if (i == s.length)
                return _Token(_Token.Type.eof);

            switch (s[i]) {
            case '[':
                i++;
                skipWhitespace();
                capture = captureWord(']');
                skipWhitespace();
                enforce(i != s.length && s[i++] == ']',
                    "Invalid character in section [" ~ capture ~ ']');
                skipWhitespace();
                if (i != s.length) {
                    const c = s[i++];
                    enforce(c == '\n' || c == '\r', "Extra text after section [" ~ capture ~ ']');
                }
                return _Token(_Token.Type.section, capture);

            case ';':
            case '#':
                i++;
                while (i != s.length) {
                    const c = s[i++];
                    if (c == '\n' || c == '\r')
                        break;
                }
                continue;

            case '\n':
            case '\r':
                i++;
                continue;

            default:
                capture = captureWord('=');
                skipWhitespace();
                enforce(i != s.length && s[i++] == '=',
                    "Invalid character in key `" ~ capture ~ '`');
                skipWhitespace();
                return _Token(_Token.Type.data, capture, captureLine());
            }
        }
    }
}

struct _SectionMeta {
    size_t offset;
    size_t[string] valueOffsets;
}

struct _Meta {
    size_t totalKeys;
    _SectionMeta[string] sections;
    string[ ] qualifiedNames;
}

enum _isEnum(T) = is(T == enum);

template _getMember(T) {
    alias _getMember(string name) = __traits(getMember, T, name);
}

alias _enumsOf(T) = Filter!(_isEnum, staticMap!(_getMember!T, __traits(allMembers, T)));

enum _metaOf(Spec) = {
    import std.traits: EnumMembers;

    size_t totalKeys;
    _SectionMeta[string] sections;
    string[ ] qNames;

    static foreach (E; _enumsOf!Spec) {{
        static assert(E.min >= 0, "Enum `" ~ E.stringof ~ "` has negative values");
        static assert(E.max < uint.max, "Enum `" ~ E.stringof ~ "` has too large values");

        enum n = size_t(E.max) + 1;
        qNames.length += n;
        _SectionMeta section = { totalKeys };
        static foreach (i, value; EnumMembers!E) {{
            enum name = __traits(identifier, EnumMembers!E[i]);
            const offset = totalKeys + value;
            section.valueOffsets[name] = offset;
            if (qNames[offset] is null)
                qNames[offset] = '[' ~ E.stringof ~ "]." ~ name;
        }}

        sections[E.stringof] = section;
        totalKeys += n;
    }}
    return _Meta(totalKeys, sections, qNames);
}();

public struct CTIni(_Spec) {
nothrow pure @nogc:
    alias Spec = _Spec;
    private enum _meta = _metaOf!Spec;

    struct Key {
    nothrow pure @nogc:
        private size_t _offset = size_t.max;

        static foreach (E; _enumsOf!Spec)
            this(E key) {
                _offset = _meta.sections[E.stringof].offset + size_t(key);
            }
    }

    private string[_meta.totalKeys] _storage;

    @disable this(string[_meta.totalKeys]);

    ref inout(string) opIndex(Key key) inout {
        return _storage[key._offset];
    }

    static foreach (E; _enumsOf!Spec)
        ref inout(string) opIndex(E key) inout {
            return this[Key(key)];
        }
}

CTIni!Spec _parse(Spec)(string source) {
    import std.exception: enforce;

    assert(__ctfe);
    CTIni!Spec ini;
    immutable meta = ini._meta;
    immutable(_SectionMeta)* curSection;
    string curSectionName;
    size_t totalSet;

    _Lexer lx = { 0, source, new char[128] };
    while (true) {
        const token = lx.getNext();
        final switch (token.type) with (_Token.Type) {
        case data:
            enforce(curSection !is null, "Unknown section [" ~ curSectionName ~ ']');
            if (const p = token.key in curSection.valueOffsets) {
                const offset = *p;
                enforce(ini._storage[offset] is null,
                    meta.qualifiedNames[offset] ~ " is declared multiple times");
                totalSet++;
                ini._storage[offset] = token.value;
            }
            break;

        case section:
            curSectionName = token.key;
            curSection = curSectionName in meta.sections;
            break;

        case eof:
            if (totalSet != meta.totalKeys)
                foreach (i, s; ini._storage[ ])
                    enforce(s !is null, meta.qualifiedNames[i] ~ " is not declared");
            return ini;
        }
    }
}

public enum CTIni!Spec parse(Spec, string source) = {
    try
        return _parse!Spec(source);
    catch (Exception e)
        throw e; // Collapse the traceback.
}();
