module program_options;

import sumtype;

private @safe:

enum _usage = q"EOF
A tool for updating Ren'Py translations.

Usage:
  renpy-update-tl [...] <project-path> <language>
EOF";

public struct ProgramOptions {
    string projectPath;
    string language;
    string renpyPath;
}

auto _parseOptions(ref ProgramOptions o, ref string[ ] args) @system {
    import std.getopt;

    return getopt(args,
        config.caseSensitive, // config.bundling,
        "renpy", "Path to Ren'Py SDK.", &o.renpyPath,
    );
}

bool _isValidLang(const(char)[ ] lang) nothrow pure @nogc {
    import utils;

    return isValidCIdent(lang) && lang != "None";
}

void _validate(ref const ProgramOptions o) pure {
    import std.exception;
    import std.path;
    import std.range;

    enforce(_isValidLang(o.language), "Invalid language: `" ~ o.language ~ '`');
    enforce(isValidPath(o.projectPath), "Invalid project path: `" ~ o.projectPath ~ '`');
    if (!o.renpyPath.empty)
        enforce(isValidPath(o.renpyPath), "Invalid Ren'Py SDK path: `" ~ o.renpyPath ~ '`');
}

public struct ParseError { }
public struct HelpRequested { }

public alias ParseResult = SumType!(ProgramOptions, ParseError, HelpRequested);

public ParseResult parse(ref string[ ] args) @system {
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
        o.projectPath = args[1];
        o.language = args[2];
        _validate(o);
    } catch (Exception e) {
        stderr.writeln(e.msg);
        return ParseResult(ParseError());
    }
    return ParseResult(o);
}
