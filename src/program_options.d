import sumtype;

@system:

private enum _usage = q"EOF
A tool for updating Ren'Py translations.

Usage:
  renpy-update-tl [...] <project-path> <language>
EOF";

struct ProgramOptions {
    string projectPath;
    string language;
    string renpyPath;
}

private auto _parseOptions(ref ProgramOptions o, ref string[ ] args) {
    import std.getopt;

    return getopt(args,
        config.caseSensitive, // config.bundling,
        "renpy", "Path to Ren'Py SDK.", &o.renpyPath,
    );
}

struct ParseError { }
struct HelpRequested { }

alias ParseResult = SumType!(ProgramOptions, ParseError, HelpRequested);

ParseResult parse(ref string[ ] args) {
    import std.getopt;
    import std.stdio;

    ProgramOptions o;
    try {
        auto info = _parseOptions(o, args);
        if (info.helpWanted) {
            defaultGetoptPrinter(_usage, info.options);
            return ParseResult(HelpRequested());
        }
        if (args.length != 3) {
            defaultGetoptFormatter(stderr.lockingTextWriter(), _usage, info.options);
            return ParseResult(ParseError());
        }
    } catch (Exception e) {
        stderr.writeln(e.msg);
        return ParseResult(ParseError());
    }
    o.projectPath = args[1];
    o.language = args[2];
    return ParseResult(o);
}
