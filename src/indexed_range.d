module indexed_range;

import std.range;
import std.traits: isIntegral;
import std.typecons: TypedefType;

struct IndexedRange(R, I) if (isRandomAccessRange!R && isIntegral!(TypedefType!I)) {
    private R _data;

    @property inout(R) data() inout {
        return _data;
    }

    alias data this;

    @property I length() {
        return I(cast(TypedefType!I)_data.length);
    }

    alias opDollar = length;

    static if (!is(immutable I == immutable size_t)) {
        @disable ref ElementType!R opIndex(size_t);

        auto ref opIndex(I i) {
            return _data[cast(size_t)i];
        }
    }
}

auto indexedRange(I, R)(R data) if (isRandomAccessRange!R && isIntegral!(TypedefType!I)) {
    return IndexedRange!(R, I)(data);
}
