module tl_file.generated.model;

nothrow pure @safe @nogc:

struct DialogueBlock {
    string location;
    string labelAndHash;
    string oldText;
    string newText;
}

struct PlainString {
    string location;
    string oldText;
}

struct Declarations {
    DialogueBlock[ ] dialogueBlocks;
    PlainString[ ] plainStrings;
}
