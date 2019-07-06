module config_file;

import std.range.primitives: empty;

import mvc.m.data: Model;

private nothrow @safe:

immutable string _configPath;

string _getenv(string name) {
    import std.process: environment;
    import std.utf: UTFException;

    try
        return environment.get(name);
    catch (UTFException)
        return null;
    catch (Exception e)
        assert(false, e.msg);
}

bool _dirExists(string path) {
    import std.file: FileException, isDir;

    try
        return isDir(path);
    catch (FileException)
        return false;
    catch (Exception e)
        assert(false, e.msg);
}

string _tryLocate(Segments...)(Segments segments) {
    import std.path: buildPath;

    static foreach (s; segments)
        if (s.empty)
            return null;
    static if (segments.length == 1)
        const path = segments[0];
    else
        const path = buildPath(segments);
    return _dirExists(path) ? path : null;
}

string _locateConfigDir() {
    import std.file: tempDir;

    // $APPDATA/
    version (Windows)
        if (const path = _tryLocate(_getenv("APPDATA")))
            return path;
    // $XDG_CONFIG_HOME/
    if (const path = _tryLocate(_getenv("XDG_CONFIG_HOME")))
        return path;
    // $USERPROFILE/.config/
    version (Windows)
        if (const path = _tryLocate(_getenv("USERPROFILE"), `.config`))
            return path;
    // $HOME/.config/
    if (const path = _tryLocate(_getenv("HOME"), `.config`))
        return path;
    // $TMPDIR/
    try
        return tempDir();
    catch (Exception)
        return null;
}

shared static this() {
    import std.path: buildPath;

    if (const path = _locateConfigDir())
        _configPath = path != `.` ? buildPath(path, `renpy-update-tl/gui.json`) : `gui.json`;
}

public Model parseConfig() {
    import std.json;
    import std.mmfile;
    import std.typecons: scoped;

    Model model;
    try {
        auto config = () @trusted {
            auto mmf = scoped!MmFile(_configPath);
            return parseJSON(cast(const(char)[ ])(cast(MmFile)mmf)[ ], 1000);
        }();
        try
            model.uiLanguage = config["uiLanguage"].str;
        catch (JSONException) { }
        try
            model.trySetRenpySDKPath(config["renpySDKPath"].str);
        catch (JSONException) { }
        try {
            model.trySetProjectPath(config["projectPath"].str);
            model.busy = model.projectPath.empty;
        } catch (JSONException) { }
        try
            model.firstRun = config["firstRun"].boolean;
        catch (JSONException) { }
    } catch (Exception) { }
    return model;
}

public void dumpConfig(ref const Model model) {
    import std.file: mkdirRecurse, write;
    import std.json;
    import std.path: dirName;

    if (_configPath.empty)
        return;
    try {
        const JSONValue j = [
            "uiLanguage":   JSONValue(model.uiLanguage),
            "renpySDKPath": JSONValue(model.renpySDKPath),
            "projectPath":  JSONValue(model.projectPath),
            "firstRun":     JSONValue(model.firstRun),
        ];
        mkdirRecurse(dirName(_configPath));
        write(_configPath, j.toJSON());
    } catch (Exception) { }
}
