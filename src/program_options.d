module program_options;

import sumtype;

private @safe:

enum _usage = q"EOF
A tool for updating Ren'Py translations.

Usage:
  renpy-update-tl [...] <project-path> <language> [<language>...]
EOF";

public struct ProgramOptions {
    string projectPath;
    string[ ] languages;
    string renpyPath;
    string outputDir;
    uint jobs;
    bool versionRequested;
    string debugLanguageTemplate;
}

auto _parseOptions(ref ProgramOptions o, ref string[ ] args) @system {
    import std.getopt;

    return getopt(args,
        config.caseSensitive, config.bundling,

        "renpy",
            "Path to Ren'Py SDK.",
            &o.renpyPath,
        "o|output-dir",
            "Directory to place merged files in, instead of overwriting source files.",
            &o.outputDir,
        "j",
            "Number of concurrent workers. 0 (default) - use all available CPU cores.",
            &o.jobs,
        "assume-fresh",
            "Bypass Ren'Py invocation (debug option).",
            &o.debugLanguageTemplate,
        "V|version",
            "Print version and exit.",
            &o.versionRequested,
    );
}

bool _isValidLang(const(char)[ ] lang) nothrow pure @nogc {
    import utils;

    return isValidCIdent(lang) && lang != "None";
}

void _validate(ref const ProgramOptions o) pure {
    import std.exception: enforce;
    import std.path;
    import std.range.primitives: empty;

    foreach (language; o.languages)
        enforce(_isValidLang(language), "Invalid language: `" ~ language ~ '`');
    enforce(isValidPath(o.projectPath), "Invalid project path: `" ~ o.projectPath ~ '`');
    if (!o.renpyPath.empty)
        enforce(isValidPath(o.renpyPath), "Invalid Ren'Py SDK path: `" ~ o.renpyPath ~ '`');
    if (!o.outputDir.empty)
        enforce(isValidPath(o.outputDir), "Invalid output directory: `" ~ o.outputDir ~ '`');
    if (!o.debugLanguageTemplate.empty) {
        enforce(
            _isValidLang(o.debugLanguageTemplate),
            "Invalid language: `" ~ o.debugLanguageTemplate ~ '`',
        );
        enforce(o.renpyPath.empty, "`--assume-fresh` and `--renpy` cannot be used together");
    }
}

void _enforceDir(string path) {
    import std.exception;
    import std.file;

    enforce(isDir(path), "Not a directory: `" ~ path ~ '`');
}

void _validateImpure(ref const ProgramOptions o) {
    import std.file: FileException;
    import std.path: buildPath;
    import std.range.primitives: empty;

    _enforceDir(o.projectPath);
    if (!o.renpyPath.empty)
        _enforceDir(o.renpyPath);
    if (!o.outputDir.empty)
        try
            _enforceDir(o.outputDir);
        catch (FileException) { } // Nonexistent output directory is OK.
    if (!o.debugLanguageTemplate.empty)
        _enforceDir(buildPath(o.projectPath, `game/tl`, o.debugLanguageTemplate));
}

public struct ParseError { }
public struct HelpRequested { }

public alias ParseResult = SumType!(ProgramOptions, ParseError, HelpRequested);

public ParseResult parse(ref string[ ] args) @system {
    import std.getopt;
    import std.stdio;
    import version_;

    ProgramOptions o;
    try {
        auto info = _parseOptions(o, args);
        if (info.helpWanted) {
            defaultGetoptPrinter(_usage, info.options);
            return ParseResult(HelpRequested());
        }
        if (o.versionRequested) {
            enum s = 'v' ~ programVersion ~ '\n';
            write(s);
            return ParseResult(HelpRequested());
        }
        if (args.length < 3) {
            defaultGetoptFormatter(stderr.lockingTextWriter(), _usage, info.options);
            return ParseResult(ParseError());
        }
        o.projectPath = args[1];
        o.languages = args[2 .. $];
        _validate(o);
        _validateImpure(o);
    } catch (Exception e) {
        stderr.writeln(e.msg);
        return ParseResult(ParseError());
    }
    return ParseResult(o);
}
