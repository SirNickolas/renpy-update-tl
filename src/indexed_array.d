module indexed_array;

import std.traits: isIntegral;
import std.typecons: TypedefType;

struct IndexedArray(T, I) if (isIntegral!(TypedefType!I)) {
    private T[ ] _data;

    @property I length() const nothrow pure @safe @nogc {
        return I(cast(TypedefType!I)_data.length);
    }

    @property inout(T)[ ] data() inout {
        return _data;
    }

    ref inout(T) opIndex(I i) inout {
        return _data[cast(size_t)i];
    }
}

auto indexedArray(I, T)(T[ ] data) nothrow pure @safe @nogc if (isIntegral!(TypedefType!I)) {
    return IndexedArray!(T, I)(data);
}
