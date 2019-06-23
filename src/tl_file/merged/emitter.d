module tl_file.merged.emitter;

import std.array: Appender;
import std.ascii: newline;
import std.typecons: Flag, Yes, No;

import tlg = tl_file.generated.model;
import tlu = tl_file.user.model;
import tlm = tl_file.merged.model;

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
        import std.range: empty;

        if (!text.empty)
            write(text, newline);
    }

    void writeParaCommented(const(char)[ ] text) {
        import std.range: empty;
        import std.string: lineSplitter;

        foreach (line; text.lineSplitter())
            if (line.empty)
                write(_ct!('#' ~ newline));
            else
                write(`# `, line, newline);
    }

    /+
        Dialogue blocks.
    +/
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

    /+
        Plain strings.
    +/
    void emit(Flag!q{exact} exact, ref const tlu.PlainString u, ref const tlg.PlainString g) {
        write(_ct!(newline ~ `    # `), g.location, newline);
        if (!exact)
            write(_ct!(`    # TODO: MODIFIED.` ~ newline));
        writePara(u.contents0);
        write(`    old `, g.oldText, newline);
        if (!exact)
            write(
                `    # old `, u.oldText,
                _ct!(` # OUTDATED; delete this line when no longer needed.` ~ newline),
            );
        writePara(u.contents1);
    }

    void emitOutdated(ref const tlu.PlainString u) {
        // We've lost location. Do we care about it much?..
        write(_ct!(
            newline ~ `# TODO: OUTDATED; delete these lines when no longer needed.` ~ newline
        ));
        writeParaCommented(u.contents0);
        write(`#     old `, u.oldText, newline);
        writeParaCommented(u.contents1);
    }

    void emit(ref const tlg.PlainString g) {
        write(_ct!(
            newline ~
            `    # `), g.location, _ct!(newline ~
            `    # TODO: NEW.` ~ newline ~
            `    old `), g.oldText, _ct!(newline ~
            `    new ""` ~ newline),
        );
    }

    void emit(
        ref const tlm.Results d,
        ref const tlu.Declarations ud,
        ref const tlg.Declarations gd,
    ) {
        import std.range: empty;
        import sumtype;
        import utils: unreachable;

        bool nl;
        // Summary.
        if (!ud.summary.empty) {
            write(ud.summary, newline);
            nl = true;
        }

        // Dialogue and unrecognized blocks.
        size_t i = 0;
        foreach (b; d.blocks) {
            if (nl)
                write(newline);
            else
                nl = true;
            b.match!(
                (tlm.Matched b) => ud.blocks[b.uIndex].match!(
                    (ref const tlu.DialogueBlock u) =>
                        emit(Yes.exact, u, gd.dialogueBlocks[i++]),
                    (tlu.UnrecognizedBlock _) => unreachable,
                ),
                (tlm.InexactlyMatched b) => ud.blocks[b.uIndex].match!(
                    (ref const tlu.DialogueBlock u) =>
                        emit(No.exact, u, gd.dialogueBlocks[i++]),
                    (tlu.UnrecognizedBlock _) => unreachable,
                ),
                (tlm.NonMatched b) => ud.blocks[b.uIndex].match!(
                    (ref const tlu.DialogueBlock u) =>
                        emitOutdated(u),
                    (tlu.UnrecognizedBlock u) =>
                        emit(u),
                ),
                (tlm.New _) => emit(gd.dialogueBlocks[i++]),
            );
        }
        assert(i == gd.dialogueBlocks.length);

        // Plain strings.
        if (d.plainStrings.empty)
            return;
        i = 0;
        if (nl)
            write(newline);
        write(`translate `, lang, _ct!(` strings:` ~ newline));
        foreach (ps; d.plainStrings)
            ps.match!(
                (tlm.Matched ps) =>
                    emit(Yes.exact, ud.plainStrings[ps.uIndex], gd.plainStrings[i++]),
                (tlm.InexactlyMatched ps) =>
                    emit(No.exact, ud.plainStrings[ps.uIndex], gd.plainStrings[i++]),
                (tlm.NonMatched ps) =>
                    emitOutdated(ud.plainStrings[ps.uIndex]),
                (tlm.New _) =>
                    emit(gd.plainStrings[i++]),
            );
        assert(i == gd.plainStrings.length);
    }
}

public void emit(
    ref Appender!(char[ ]) o,
    ref const tlm.Results d,
    ref const tlu.Declarations ud,
    ref const tlg.Declarations gd,
    const(char)[ ] language,
) @trusted {
    _Emitter(&o, language).emit(d, ud, gd);
}
