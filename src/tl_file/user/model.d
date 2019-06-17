module tl_file.user.model;

import sumtype;

nothrow pure @safe @nogc:

struct DialogueBlock {
    string summary; // After location.
    string contents0;
    string oldText;
    string contents1;
}

struct UnrecognizedBlock {
    string contents;
}

alias Block = SumType!(DialogueBlock, UnrecognizedBlock);

struct PlainString {
    string contents0; // After location.
    string oldText;
    string contents1;
}

struct Declarations {
    string summary;
    Block[ ] blocks;
    PlainString[ ] plainStrings;
}
