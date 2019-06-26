module tl_file.lang_pack;

import tlu = tl_file.user.model;
import tlg = tl_file.generated.model;
import tlm = tl_file.merged.model;

@safe:

// Caution: this struct has reference semantics.
struct LangPack(D) {
    D[string] files;
}

auto collect(alias parseFile, Args...)(string path, auto ref Args args) @system
in {
    import std.path;

    assert(isAbsolute(path));
}
do {
    import std.algorithm;
    import std.array: array, assocArray;
    import std.file: SpanMode, dirEntries;
    import std.functional: forward;
    import std.parallelism: task, taskPool;
    import std.path: extension, relativePath;
    import std.range: tee;
    import std.typecons: tuple;

    return LangPack!(typeof(parseFile("", forward!args)))(
        dirEntries(path, SpanMode.breadth)
        .filter!(e => extension(e.name).among!(".rpy", ".rpym") && e.isFile)
        .map!(e => task!parseFile(e.name, forward!args))
        .cache()
        .tee!(t => taskPool.put(t))
        .array()
        .map!(t => tuple(relativePath(t.args[0], path), t.workForce()))
        .assocArray()
    );
}

// This function should be private, but the compiler doesn't allow.
tlm.Results _mergeDecls(
    string filename,
    ref const tlg.Declarations gd,
    ref const LangPack!(tlu.Declarations) ulp,
) nothrow {
    import std.array: array;
    import std.range: repeat;
    import tlm = tl_file.merged;

    if (const p = filename in ulp.files)
        return tlm.merge(*p, gd);
    // A file is present in generated langpack, but not in user one.
    enum new_ = tlm.MergeResult(tlm.New.init);
    return tlm.Results(
        repeat(new_, gd.dialogueBlocks.length).array(),
        repeat(new_, gd.plainStrings.length).array(),
    );
}

LangPack!(tlm.Results) merge(
    const LangPack!(tlu.Declarations) ulp,
    const LangPack!(tlg.Declarations) glp,
) @system {
    import std.algorithm.iteration;
    import std.array: appender, array, assocArray;
    import std.parallelism: task, taskPool;
    import std.range: tee;
    import std.typecons: tuple;
    import tlm = tl_file.merged;

    return typeof(return)(
        glp.files.byKeyValue()
        .map!(kv => task!_mergeDecls(kv.key, kv.value, ulp))
        .cache()
        .tee!(t => taskPool.put(t))
        .array()
        .map!(t => tuple(t.args[0], t.workForce()))
        .assocArray()
    );
}
