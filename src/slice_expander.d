module slice_expander;

import std.traits: isDynamicArray;

nothrow pure @safe @nogc:

struct Expander(T) if (isDynamicArray!T) {
nothrow pure @nogc:
    private {
        version (assert) T _data;
        T _cur;
    }

    this(T data) {
        version (assert) _data = data;
    }

    void reset() { _cur = null; }

    void reset(T s) @trusted
    in {
        version (assert)
            assert(s.ptr >= _data.ptr && s.ptr + s.length <= _data.ptr + _data.length);
    }
    do {
        _cur = s;
    }

    @property inout(T) get() inout { return _cur; }

    void expandTo(T s) @trusted
    in {
        version (assert)
            assert(s.ptr >= _data.ptr && s.ptr + s.length <= _data.ptr + _data.length);
    }
    do {
        import std.range.primitives: empty;

        if (_cur.empty)
            _cur = s;
        else {
            assert(s.ptr >= _cur.ptr);
            _cur = _cur.ptr[0 .. s.ptr - _cur.ptr + s.length];
        }
    }
}

auto expander(T)(T data) if (isDynamicArray!T) {
    return Expander!T(data);
}
