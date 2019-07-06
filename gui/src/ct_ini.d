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

    string captureLine() nothrow @nogc {
        const start = i;
        while (i != s.length)
            if (s[i++] == '\n')
                return s[start .. i - 1];
        return s[start .. $];
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
                enforce(i == s.length || s[i++] == '\n',
                    "Extra text after section [" ~ capture ~ ']');
                return _Token(_Token.Type.section, capture);

            case ';':
                i++;
                while (i != s.length && s[i++] != '\n') { }
                continue;

            case '\n':
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

enum _metaOf(UserSpec) = {
    import std.traits: EnumMembers;

    size_t totalKeys;
    _SectionMeta[string] sections;
    string[ ] qNames;

    static foreach (E; _enumsOf!UserSpec) {{
        static assert(E.min >= 0, "Enum `" ~ E.stringof ~ "` has negative values");
        static assert(E.max < uint.max, "Enum `" ~ E.stringof ~ "` has too large values");

        const n = size_t(E.max) + 1;
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
    bool[ini._meta.totalKeys] set;
    size_t totalSet;

    _Lexer lx = { 0, source };
    while (true) {
        const token = lx.getNext();
        final switch (token.type) with (_Token.Type) {
        case data:
            enforce(curSection !is null, "Anonymous sections are not supported");
            if (const p = token.key in curSection.valueOffsets) {
                const offset = *p;
                enforce(!set[offset], meta.qualifiedNames[offset] ~ " is declared multiple times");
                set[offset] = true;
                totalSet++;
                ini._storage[offset] = token.value;
            } else
                throw new Exception("Unknown field [" ~ curSectionName ~ "]." ~ token.key);
            break;

        case section:
            curSectionName = token.key;
            curSection = curSectionName in meta.sections;
            enforce(curSection !is null, "Unknown section [" ~ curSectionName ~ ']');
            break;

        case eof:
            if (totalSet != meta.totalKeys)
                foreach (i, b; set[ ])
                    enforce(b, meta.qualifiedNames[i] ~ " is not declared");
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
