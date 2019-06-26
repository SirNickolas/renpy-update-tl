module renpy_interaction;

import std.path: isValidPath;
import std.process: Pid;

@safe:

string locateRenpyInSdk(const(char)[ ] renpySdkPath)
in {
    assert(isValidPath(renpySdkPath));
}
out (renpy) {
    assert(isValidPath(renpy));
}
do {
    import std.conv: text;
    import std.file: FileException, isFile;

    version (OSX)
        enum prefix = `/lib/darwin-`;
    else version (Posix)
        enum prefix = `/lib/linux-`;
    else
        enum prefix = `\lib\windows-`;
    version (D_LP64)
        const string[2] archs = [`x86_64`, `i686`];
    else
        const string[1] archs = [`i686`];
    version (Posix)
        enum filename = `/renpy`;
    else
        enum filename = `\renpy.exe`;

    foreach (arch; archs[ ]) {
        const renpyPath = text(renpySdkPath, prefix, arch, filename);
        try
            if (isFile(renpyPath))
                return renpyPath;
        catch (FileException) { }
    }
    throw new Exception(text("No `renpy` in `", renpySdkPath, '`'));
}

private string[2] _makeTempLang(const(char)[ ] projectPath) {
    import std.exception: enforce;
    import std.file: isDir, mkdir;
    import std.path: buildPath, chainPath;
    import std.string: succ;

    enforce(isDir(chainPath(projectPath, `game/tl`)), "`game/tl` is not a directory");
    string tempLang = `a`;
    while (true) {
        const path = buildPath(projectPath, `game/tl`, tempLang);
        try {
            mkdir(path); // Check and make atomically.
            return [path, tempLang];
        } catch (Exception) { }
        tempLang = succ(tempLang);
    }
}

struct GenerationResult {
    Pid pid;
    string path;
}

GenerationResult generateTranslations(const(char)[ ] renpy, const(char)[ ] projectPath)
in {
    import std.path: isAbsolute;

    assert(isValidPath(renpy));
    assert(isValidPath(projectPath));
    assert(isAbsolute(projectPath));
}
out (result) {
    assert(isValidPath(result.path));
}
do {
    import std.process: spawnProcess;

    const tempLang = _makeTempLang(projectPath);
    const char[ ][6] args = [renpy, projectPath, `translate`, `--empty`, `--no-todo`, tempLang[1]];
    return GenerationResult(spawnProcess(args[ ]), tempLang[0]);
}
