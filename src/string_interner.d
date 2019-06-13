module string_interner;

@safe:

struct StringInterner {
pure:
    private immutable(char)*[string] _aa;

    this(this) {
        _aa = _aa.dup;
    }

    string intern(const(char)[ ] s) nothrow @trusted {
        if (const p = s in _aa)
            return (*p)[0 .. s.length];
        const owned = s.idup;
        _aa[owned] = owned.ptr;
        return owned;
    }
}
