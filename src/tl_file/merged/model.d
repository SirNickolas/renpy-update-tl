module tl_file.merged.model;

import sumtype;

nothrow pure @safe @nogc:

struct MatchedBlock {
    uint uIndex = uint.max;
}

struct InexactlyMatchedBlock {
    uint uIndex = uint.max;
}

// Either unrecognized or deleted.
struct NonMatchedBlock {
    uint uIndex = uint.max;
}

// Added.
struct NewBlock { }

alias Block = SumType!(MatchedBlock, InexactlyMatchedBlock, NonMatchedBlock, NewBlock);
