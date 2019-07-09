module slice_expander;

import std.traits: isDynamicArray;

nothrow pure @safe @nogc:

struct Expander(T) if (isDynamicArray!T) {
nothrow pure @nogc:
    private {
        version (assert) T _data;
        T _cur;
    }

    this(T data, T cur = null) {
        version (assert) _data = data;
        reset(cur);
    }

    void reset(T s = null) @trusted
    in {
        version (assert)
            assert(
                s is null || (s.ptr >= _data.ptr && s.ptr + s.length <= _data.ptr + _data.length)
            );
    }
    do {
        _cur = s;
    }

    @property inout(T) get() inout { return _cur; }

    void expandTo(T s) @trusted {
        if (s is null)
            return;
        version (assert)
            assert(s.ptr >= _data.ptr && s.ptr + s.length <= _data.ptr + _data.length);
        if (_cur is null)
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
