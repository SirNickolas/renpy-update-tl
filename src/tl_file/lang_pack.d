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
    import std.array: array;
    import std.file: SpanMode, dirEntries;
    import std.functional: forward;
    import std.parallelism: task, taskPool;
    import std.path: extension, relativePath;
    import std.range: tee;

    LangPack!(typeof(parseFile("", forward!args))) result;

    dirEntries(path, SpanMode.breadth)
        .filter!(e => extension(e.name).among!(".rpy", ".rpym") && e.isFile)
        .map!(e => task!parseFile(e.name, forward!args))
        .cache()
        .tee!(t => taskPool.put(t))
        .array()
        .each!(t => result.files[relativePath(t.args[0], path)] = t.workForce());

    return result;
}

LangPack!(tlm.Results) merge(
    const LangPack!(tlu.Declarations) ulp,
    const LangPack!(tlg.Declarations) glp,
) nothrow {
    import std.array: appender, array, assocArray;
    import std.range: repeat;
    import std.typecons: Tuple, tuple;
    import tlm = tl_file.merged;

    typeof(return) result;

    auto app = appender!(Tuple!(string, tlm.Results)[ ]);
    app.reserve(glp.files.length);
    // TODO: Parallelize.
    foreach (ref kv; glp.files.byKeyValue()) {
        const filename = kv.key;
        if (const p = filename in ulp.files)
            app ~= tuple(filename, tlm.merge(*p, kv.value));
        else {
            // A file is present in generated langpack, but not in user one.
            enum new_ = tlm.MergeResult(tlm.New.init);
            app ~= tuple(filename, tlm.Results(
                repeat(new_, kv.value.dialogueBlocks.length).array(),
                repeat(new_, kv.value.plainStrings.length).array(),
            ));
        }
    }
    result.files = assocArray(app.data);

    return result;
}
