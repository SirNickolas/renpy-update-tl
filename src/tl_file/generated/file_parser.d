module tl_file.generated.file_parser;

import tl_file.generated.model;

@safe:

Declarations parseFile(string filename) @trusted {
    import std.mmfile;
    import std.typecons: scoped;
    import tl_file.generated.parser;

    auto mmf = scoped!MmFile(filename);
    return parse(cast(const(char)[ ])(cast(MmFile)mmf)[ ]);
}
