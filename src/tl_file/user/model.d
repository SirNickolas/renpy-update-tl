module tl_file.user.model;

import sumtype;

nothrow pure @safe @nogc:

enum TranslationState: ubyte {
    blank,
    identical,
    translated,
}

struct DialogueBlock {
    string summary; // After location.
    string labelAndHash;
    string contents0;
    string oldVoice;
    string oldText;
    string contents1;
    string newVoice;
    string contents2;
    TranslationState state;
}

struct UnrecognizedBlock {
    string contents;
}

alias Block = SumType!(DialogueBlock, UnrecognizedBlock);

struct PlainString {
    string contents0; // After location.
    string oldText;
    string contents1;
    TranslationState state;
}

struct Declarations {
    string summary;
    Block[ ] blocks;
    PlainString[ ] plainStrings;
}
