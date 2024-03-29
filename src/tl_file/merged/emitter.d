module tl_file.merged.emitter;

import std.array: Appender;
import std.ascii: newline;
import std.range.primitives: empty;
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

bool _isBlankPara(const(char)[ ] text) @nogc {
    import std.algorithm;
    import std.ascii: isWhite;
    import std.string: lineSplitter;
    import std.utf: byCodeUnit;

    return text.lineSplitter().all!((line) {
        // ^\s*(?:$|#\s*(?:$|TODO: ))
        auto s = line.byCodeUnit().stripLeft!isWhite();
        if (s.empty)
            return true;
        if (!s.skipOver('#'))
            return false;
        s.skipOver!isWhite();
        return s.empty || s.startsWith(`TODO: `.byCodeUnit());
    });
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
        writePara(u.summary);
        write(`translate `, lang, ` `, g.labelAndHash, _ct!(':' ~ newline ~ newline));
        writePara(u.contents0);
        if (!g.oldVoice.empty)
            write(`    # `, g.oldVoice, newline);
        write(`    # `, g.oldText, newline);
        string newText;
        if (!exact)
            final switch (u.state) with (tlu.TranslationState) {
            case blank:     newText = g.newText; break;
            case identical: newText = g.oldText; break;
            case translated:
                write(
                    `    # `, u.oldText,
                    _ct!(` # TODO: OUTDATED; delete this line when no longer needed.` ~ newline),
                );
                break;
            }
        writePara(u.contents1);
        // If voice has been translated, keep the translated version. Otherwise, silently update.
        const newVoice = u.newVoice != u.oldVoice ? u.newVoice : g.oldVoice;
        if (!newVoice.empty)
            write(`    `, newVoice, newline);
        if (!newText.empty)
            write(`    `, newText, newline);
        else
            writePara(u.contents2);
    }

    void emitOutdated(ref const tlu.DialogueBlock u) {
        if (u.state != tlu.TranslationState.translated &&
            _isBlankPara(u.summary) && _isBlankPara(u.contents0) && _isBlankPara(u.contents1)
        )
            return; // There was no translation; delete this block.

        // We've lost location. Do we care about it much?..
        write(_ct!(`# TODO: OUTDATED; delete these lines when no longer needed.` ~ newline));
        writeParaCommented(u.summary);
        write(`# translate `, lang, ` `, u.labelAndHash, _ct!(':' ~ newline ~ '#' ~ newline));
        writeParaCommented(u.contents0);
        if (!u.oldVoice.empty)
            write(`#     # `, u.oldVoice, newline);
        write(`#     # `, u.oldText, newline);
        writeParaCommented(u.contents1);
        if (!u.newVoice.empty)
            write(`#     `, u.newVoice, newline);
        writeParaCommented(u.contents2);
    }

    void emit(ref const tlu.UnrecognizedBlock u) {
        writePara(u.contents);
    }

    void emit(ref const tlg.DialogueBlock g) {
        const hasVoice = !g.oldVoice.empty;
        write(
            `# `, g.location, _ct!(newline ~
            `# TODO: NEW.` ~ newline ~
            `translate `), lang, ` `, g.labelAndHash, _ct!(':' ~ newline ~ newline ~
            `    # `),
        );
        if (hasVoice)
            write(g.oldVoice, _ct!(newline ~ `    # `));
        write(g.oldText, _ct!(newline ~ `    `));
        if (hasVoice)
            write(g.oldVoice, _ct!(newline ~ `    `));
        write(g.newText, newline);
    }

    /+
        Plain strings.
    +/
    void emit(Flag!q{exact} exact, ref const tlu.PlainString u, ref const tlg.PlainString g) {
        write(_ct!(newline ~ `    # `), g.location, newline);
        writePara(u.contents0);
        write(`    old `, g.oldText, newline);
        if (!exact)
            final switch (u.state) with (tlu.TranslationState) {
            case blank:
                break;
            case identical:
                write(`    new `, g.oldText, newline);
                return;
            case translated:
                write(
                    `    # old `, u.oldText,
                    _ct!(` # TODO: OUTDATED; delete this line when no longer needed.` ~ newline),
                );
                break;
            }
        writePara(u.contents1);
    }

    void emitOutdated(ref const tlu.PlainString u) {
        if (u.state != tlu.TranslationState.translated && _isBlankPara(u.contents0))
            return; // There was no translation; delete this pair.

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
            const streamPos = o.data.length;
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
            nl = o.data.length != streamPos;
        }
        assert(i == gd.dialogueBlocks.length);

        // Plain strings.
        if (d.plainStrings.empty)
            return;
        i = 0;
        write(nl ? _ct!(newline ~ `translate `) : `translate `, lang, _ct!(` strings:` ~ newline));
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
