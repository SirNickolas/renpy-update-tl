import po = program_options;

private @system:

extern(C) __gshared string[ ] rt_options = ["gcopt=gc:precise cleanup:none"];

int _run(const po.ProgramOptions options) {
    import std.algorithm.searching: canFind;
    import std.array: appender;
    import std.path: chainPath;
    import std.stdio;
    import stdf = std.file;

    import tlg = tl_file.generated;
    import tlu = tl_file.user;

    const source = stdf.readText(
        chainPath(options.projectPath, "game/tl", options.language, "script.rpy")
    );
    // auto decls = tlg.parse(source);
    // writeln(decls.dialogueBlocks.length, ' ', decls.plainStrings.length);
    auto decls = tlu.parse(source, options.language);
    writeln(decls.blocks.length, ' ', decls.plainStrings.length);
    auto app = appender!(char[ ]);
    tlu.emit(app, decls);
    stdf.write("test.rpy", app.data);
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
