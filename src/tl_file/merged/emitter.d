module tl_file.merged.emitter;

import std.array: Appender;
import std.ascii: newline;
import std.range: empty;
import std.typecons: Flag, Yes, No;

import tl_file.merged.model;
import tlg = tl_file.generated.model;
import tlu = tl_file.user.model;

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

enum _ct(alias x) = x;

struct _Emitter {
nothrow pure:
    Appender!(char[ ])* o;
    const(char)[ ] lang;

    void write(Args...)(Args args) {
        import std.range: chain;

        *o ~= chain(_byCodeUnit(args).expand);
    }

    void writePara(const(char)[ ] text) {
        if (!text.empty)
            write(text, newline);
    }

    void writeParaCommented(const(char)[ ] text) {
        import std.range: empty;
        import std.string: lineSplitter;

        foreach (line; text.lineSplitter())
            if (line.empty)
                *o ~= _ct!('#' ~ newline);
            else
                write(`# `, line, newline);
    }

    void emit(Flag!q{exact} exact, ref const tlu.DialogueBlock u, ref const tlg.DialogueBlock g) {
        write(`# `, g.location, newline);
        if (!exact)
            write(_ct!(`# TODO: MODIFIED.` ~ newline));
        writePara(u.summary);
        write(`translate `, lang, ` `, g.labelAndHash, _ct!(':' ~ newline ~ newline));
        writePara(u.contents0);
        write(`    # `, g.oldText, newline);
        if (!exact)
            write(
                `    # `, u.oldText,
                _ct!(` # OUTDATED; delete this line when no longer needed.` ~ newline),
            );
        writePara(u.contents1);
    }

    void emitOutdated(ref const tlu.DialogueBlock u) {
        // We've lost location. Do we care about it much?..
        write(_ct!(`# TODO: OUTDATED; delete these lines when no longer needed.` ~ newline));
        writeParaCommented(u.summary);
        write(`# translate `, lang, ` `, u.labelAndHash, _ct!(':' ~ newline ~ '#' ~ newline));
        writeParaCommented(u.contents0);
        write(`#     # `, u.oldText, newline);
        writeParaCommented(u.contents1);
    }

    void emit(ref const tlu.UnrecognizedBlock u) {
        writePara(u.contents);
    }

    void emit(ref const tlg.DialogueBlock g) {
        write(
            `# `, g.location, _ct!(newline ~
            `# TODO: NEW.` ~ newline ~
            `translate `), lang, ` `, g.labelAndHash, _ct!(':' ~ newline ~ newline ~
            `    # `), g.oldText, _ct!(newline ~
            `    `), g.newText, newline,
        );
    }

    void emit(
        ref const Declarations d,
        ref const tlu.Declarations ud,
        ref const tlg.Declarations gd,
    ) {
        import sumtype;
        import utils: case_, unreachable;

        bool nl;
        if (!ud.summary.empty) {
            write(ud.summary, newline);
            nl = true;
        }
        size_t i = 0;
        foreach (b; d.blocks) {
            if (nl)
                *o ~= newline;
            else
                nl = true;
            b.match!(
                (MatchedBlock b) => ud.blocks[b.uIndex].match!(
                    case_!(const tlu.DialogueBlock, (ref u) =>
                        emit(Yes.exact, u, gd.dialogueBlocks[i++])
                    ),
                    (tlu.UnrecognizedBlock _) => unreachable,
                ),
                (InexactlyMatchedBlock b) => ud.blocks[b.uIndex].match!(
                    case_!(const tlu.DialogueBlock, (ref u) =>
                        emit(No.exact, u, gd.dialogueBlocks[i++])
                    ),
                    (tlu.UnrecognizedBlock _) => unreachable,
                ),
                (NonMatchedBlock b) => ud.blocks[b.uIndex].match!(
                    case_!(const tlu.DialogueBlock, (ref u) =>
                        emitOutdated(u)
                    ),
                    (tlu.UnrecognizedBlock u) =>
                        emit(u),
                ),
                (NewBlock _) => emit(gd.dialogueBlocks[i++]),
            );
        }
        write(_ct!(newline ~ `# TODO: translate `), lang, _ct!(` strings.` ~ newline));
        /+
        foreach (ref b; d.blocks) {
            if (nl)
                o ~= newline;
            else
                nl = true;
            b.match!(
                (scope ref const DialogueBlock db) {
                    o ~= _ct!(`# stdin.rpy:0` ~ newline);
                    o._writePara(db.summary);
                    o ~= _ct!(`translate english label_abcdef01:` ~ newline ~ newline);
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
            o ~= _ct!(`translate english strings:` ~ newline);
            foreach (ref ps; d.plainStrings) {
                o ~= _ct!(newline ~ `    # stdin.rpy:0` ~ newline);
                o._writePara(ps.contents0);
                o._write(`    old `, ps.oldText, newline);
                o._writePara(ps.contents1);
            }
        }
        +/
    }
}

public void emit(
    ref Appender!(char[ ]) o,
    ref const Declarations d,
    ref const tlu.Declarations ud,
    ref const tlg.Declarations gd,
    const(char)[ ] language,
) @trusted {
    _Emitter(&o, language).emit(d, ud, gd);
}
