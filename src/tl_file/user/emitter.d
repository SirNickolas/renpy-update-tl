module tl_file.user.emitter;

import std.array: Appender;
import std.ascii: newline;
import std.range: empty;

import tl_file.user.model;

private nothrow pure @safe:

auto _byCodeUnit() @nogc {
    import std.typecons;

    return tuple();
}

auto _byCodeUnit(Args...)(const(char)[ ] head, Args tail) @nogc {
    import std.typecons: tuple;
    import std.utf: byCodeUnit;

    return tuple(head.byCodeUnit(), _byCodeUnit(tail).expand);
}

void _write(Args...)(ref Appender!(char[ ]) o, Args args) {
    import std.range: chain;

    o ~= chain(_byCodeUnit(args).expand);
}

void _writePara(ref Appender!(char[ ]) o, const(char)[ ] text) {
    if (!text.empty)
        o._write(text, newline);
}

public void emit(ref Appender!(char[ ]) o, ref const Declarations d) {
    import sumtype;

    bool nl;
    if (!d.summary.empty) {
        o._write(d.summary, newline);
        nl = true;
    }
    foreach (ref b; d.blocks) {
        if (nl)
            o ~= newline;
        else
            nl = true;
        b.match!(
            (scope ref const DialogueBlock db) {
                o ~= `# stdin.rpy:0` ~ newline;
                o._writePara(db.summary);
                o ~= `translate english label_abcdef01:` ~ newline ~ newline;
                o._writePara(db.contents0);
                o._write(`    # `, db.oldText, newline);
                o._writePara(db.contents1);
            },
            (scope ref const UnrecognizedBlock ub) => o._write(ub.contents, newline),
        );
    }
    if (!d.plainStrings.empty) {
        if (nl)
            o ~= newline;
        /+ else
            nl = true; +/
        o ~= `translate english strings:` ~ newline;
        foreach (ref ps; d.plainStrings) {
            o ~= newline ~ `    # stdin.rpy:0` ~ newline;
            o._writePara(ps.contents0);
            o._write(`    old `, ps.oldText, newline);
            o._writePara(ps.contents1);
        }
    }
}
