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
    import tlm = tl_file.merged;

    const uSource = stdf.readText(
        chainPath(options.projectPath, "game/tl", options.language, "script.rpy")
    );
    const gSource = stdf.readText(
        chainPath(options.projectPath, "game/tl/a/script.rpy")
    );
    auto uDecls = tlu.parse(uSource, options.language);
    writeln(uDecls.blocks.length, ' ', uDecls.plainStrings.length);
    stdout.flush();
    auto gDecls = tlg.parse(gSource);
    writeln(gDecls.dialogueBlocks.length, ' ', gDecls.plainStrings.length);
    stdout.flush();
    auto mDecls = tlm.merge(uDecls, gDecls);
    auto app = appender!(char[ ]);
    tlm.emit(app, mDecls, uDecls, gDecls, options.language);
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
