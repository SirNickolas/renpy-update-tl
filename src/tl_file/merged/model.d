module tl_file.merged.model;

import sumtype;

nothrow pure @safe @nogc:

struct Matched {
    uint uIndex = uint.max;
}

struct InexactlyMatched {
    uint uIndex = uint.max;
}

// Either unrecognized or deleted.
struct NonMatched {
    uint uIndex = uint.max;
}

// Added.
struct New { }

alias MergeResult = SumType!(Matched, InexactlyMatched, NonMatched, New);

struct Results {
    MergeResult[ ] blocks;
    MergeResult[ ] plainStrings;
}
