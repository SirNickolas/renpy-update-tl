import po = program_options;

private @system:

int _run(const po.ProgramOptions options) {
    import std.algorithm.searching: canFind;
    import stdf = std.file;
    import std.path: chainPath;
    import std.stdio;

    import tlu = tl_file.user;

    const source = stdf.readText(
        chainPath(options.projectPath, "game/tl", options.language, "script.rpy")
    );
    auto decls = tlu.parse(source, options.language);
    writeln(decls.blocks.length, ' ', decls.plainStrings.length);
    return 0;
}

int main(string[ ] args) {
    import sumtype;

    return po.parse(args).match!(
        (po.HelpRequested _) => 0,
        (po.ParseError _) => 2,
        o => _run(o),
    );
}
