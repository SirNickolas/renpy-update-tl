module mvc.m.cli_runner;

private @safe:

public struct CLIResult {
    bool ok;
    string output;
}

string _locateCLITool() {
    import std.file: FileException, isFile, thisExePath;
    import std.path: buildPath, dirName;

    version (Posix)
        enum filename = `renpy-update-tl`;
    else
        enum filename = `renpy-update-tl.exe`;
    const thisDir = dirName(thisExePath());
    const s = buildPath(thisDir, filename);
    try
        if (isFile(s))
            return s;
    catch (FileException) { }
    debug {
        // Look in the parent directory as well.
        const s1 = buildPath(dirName(thisDir), filename);
        try
            if (isFile(s1))
                return s1;
        catch (FileException) { }
    }
    return filename; // Search through $PATH.
}

auto _run(string renpySDKPath, string projectPath, immutable(string)[ ] langs) {
    import std.process: Config, execute;

    const string[4] args = [_locateCLITool(), `--renpy`, renpySDKPath, projectPath];
    return execute(args[ ] ~ langs, null, Config.suppressConsole);
}

public void _run(
    string renpySDKPath,
    string projectPath,
    immutable(string)[ ] langs,
    void delegate(CLIResult) @system dg,
) @system {
    CLIResult result;
    try {
        const t = _run(renpySDKPath, projectPath, langs);
        result = CLIResult(!t.status, t.output);
    } catch (Exception e) {
        dg(CLIResult(false, e.msg));
        return;
    }
    dg(result);
}

public void runCLITool(
    string renpySDKPath,
    string projectPath,
    immutable(string)[ ] langs,
    void delegate(CLIResult) @system dg,
) @system {
    import std.parallelism: task, taskPool;

    taskPool.put(task!_run(renpySDKPath, projectPath, langs, dg));
}
