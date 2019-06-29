module mvc.m.project_scanner;

private @safe:

string[ ] _collectLangs(const(char)[ ] path) @trusted {
    import std.algorithm.iteration: cache, filter, map;
    import std.algorithm.sorting: sort;
    import std.array: array;
    import std.file: SpanMode, dirEntries;
    import std.path: baseName, buildPath;
    import std.typecons: tuple;

    import mvc.m.lang: isValidLangName;

    return
        dirEntries(buildPath(path, `game/tl`), SpanMode.shallow)
        .map!(e => tuple(baseName(e.name), e))
        .cache()
        .filter!(t => isValidLangName(t[0]) && t[1].isDir)
        .map!q{a[0]}
        .array()
        .sort()
        .release();
}

public struct ProjectScanResult {
    string path;
    string[ ] langs;

    bool opCast(B: bool)() const nothrow pure @nogc {
        import std.range.primitives: empty;

        return !path.empty;
    }
}

public ProjectScanResult scanProject(string path) nothrow {
    import std.file: FileException;
    import std.path: baseName, dirName;

    try
        return ProjectScanResult(path, _collectLangs(path));
    catch (FileException) { }
    catch (Exception e)
        assert(false, e.msg);

    // Try to move up the tree.
    string base = baseName(path);
    if (base == `tl`) {
        path = dirName(path);
        base = baseName(path);
    }
    if (base != `game`)
        return ProjectScanResult.init;
    path = dirName(path);
    try
        return ProjectScanResult(path, _collectLangs(path));
    catch (FileException)
        return ProjectScanResult.init;
    catch (Exception e)
        assert(false, e.msg);
}
