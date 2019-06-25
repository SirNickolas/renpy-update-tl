module tl_file.user.file_parser;

import tl_file.user.model;

@safe:

Declarations parseFile(string filename, string lang) {
    import std.file: read;
    import tl_file.user.parser;

    // We do not perform UTF-8 validation.
    return parse(((s) @trusted => cast(string)s)(read(filename)), lang);
}
