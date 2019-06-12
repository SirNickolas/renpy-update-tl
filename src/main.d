import po = program_options;

private @system:

int _run(const po.ProgramOptions options) {
    import std.stdio;

    writeln(options);
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
