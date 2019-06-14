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

@property ref inout(string) leadingContents(ref inout Block b) {
    // Seems that `sumtype.match` cannot return by ref. And anyway, ref lambdas require 2.086+.
    return *b.match!(
        (ref inout DialogueBlock x) => &x.summary,
        (ref inout UnrecognizedBlock x) => &x.contents,
    );
}

@property ref inout(string) trailingContents(ref inout Block b) {
    return *b.match!(
        (ref inout DialogueBlock x) => &x.contents1,
        (ref inout UnrecognizedBlock x) => &x.contents,
    );
}

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
