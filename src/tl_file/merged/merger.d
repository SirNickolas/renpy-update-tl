module tl_file.merged.merger;

import std.typecons: Typedef;

import indexed_array;
import tl_file.merged.model;
import tlg = tl_file.generated.model;
import tlu = tl_file.user.model;

private nothrow @safe:

alias _UIndex = Typedef!(uint, uint.max, q{tl_file.merged.merger._UIndex});
alias _GIndex = Typedef!(uint, uint.max, q{tl_file.merged.merger._GIndex});
alias _ConstUBlockArray = IndexedArray!(const tlu.Block, _UIndex);
alias _ConstGBlockArray = IndexedArray!(const tlg.DialogueBlock, _GIndex);

static assert(!is(_UIndex == _GIndex));

struct _GBlockInfo {
    _UIndex match;
    _GIndex nextEponymous;
    bool matchedExactly = void; // Do not inspect this if `match` is not set.
}

struct _Aux {
    IndexedArray!(_GBlockInfo, _GIndex) gBlocksInfo;
    _GIndex[string] oldTextMap;

    @disable this(this);
}

_Aux _prepare(_ConstGBlockArray gBlocks) pure {
    import std.array: uninitializedArray;

    _Aux result = {
        indexedArray!_GIndex(
            uninitializedArray!(_GBlockInfo[ ])(cast(size_t)gBlocks.length),
        ),
    };
    foreach_reverse (_i, ref b; gBlocks.data) {
        _GIndex i = cast(uint)_i;
        result.gBlocksInfo[i].match = _UIndex.init;
        if (auto p = b.oldText in result.oldTextMap) {
            result.gBlocksInfo[i].nextEponymous = *p;
            *p = i;
        } else {
            result.gBlocksInfo[i].nextEponymous = _GIndex.init;
            result.oldTextMap[b.oldText] = i;
        }
    }
    () @trusted { result.oldTextMap.rehash; }();
    return result;
}

struct _ExactMatchResults {
    // TODO: Rename them.
    _UIndex[ ] uIndices;
    _GIndex[ ] gIndices;
}

_ExactMatchResults _matchExact(ref _Aux aux, _ConstUBlockArray uBlocks) pure {
    import std.algorithm.iteration: filter, map;
    import std.array: appender, array;
    import std.range: enumerate;
    import sumtype;
    import utils: case_;

    auto uUnmatched = appender!(_UIndex[ ]);
    uUnmatched.reserve(32); // Just a random number, really.
    foreach (_ui, ref b; uBlocks.data) {
        _UIndex ui = cast(uint)_ui;
        b.match!(
            case_!(tlu.UnrecognizedBlock),
            case_!(const tlu.DialogueBlock, (ref ub) {
                if (auto p = ub.oldText in aux.oldTextMap) {
                    const gi = *p;
                    if (gi != _GIndex.init) {
                        auto gInfo = (() @trusted => &aux.gBlocksInfo[gi])();
                        assert(gInfo.match == _UIndex.init);
                        gInfo.match = ui;
                        gInfo.matchedExactly = true;
                        *p = gInfo.nextEponymous;
                        return;
                    }
                }
                uUnmatched ~= ui;
            }),
        );
    }

    auto gUnmatched =
        aux.gBlocksInfo.data
        .enumerate!uint()
        .filter!(a => a.value.match == _UIndex.init)
        .map!(a => _GIndex(a.index))
        .array();
    return _ExactMatchResults(uUnmatched.data, gUnmatched);
}

_GIndex _findBestMatch(
    string needle,
    _ConstGBlockArray gBlocks,
    const(_GIndex)[ ] gIndices,
    double maxDeviation,
) @nogc {
    import std.algorithm.comparison: levenshteinDistance;
    import std.utf: byCodeUnit;

    size_t calcThreshold(const(char)[ ] s) pure {
        pragma(inline, true);

        import std.math: lrint;

        return cast(size_t)lrint(cast(int)s.length * maxDeviation);
    }

    const needleThreshold = calcThreshold(needle);
    _GIndex result;
    size_t resultDist = size_t.max;
    // This is the main bottleneck.
    // TODO: Optimize.
    foreach (gi; gIndices) {
        const s = gBlocks[gi].oldText;
        const threshold = needle.length >= s.length ? needleThreshold : calcThreshold(s);
        // FIXME: This is impure since it `malloc`ates memory. On each iteration, yes.
        const dist = levenshteinDistance(needle.byCodeUnit(), s.byCodeUnit());
        if (dist <= threshold && dist < resultDist) {
            result = cast()gi;
            resultDist = dist;
        }
    }
    return result;
}

struct _InexactMatchResults {
    _GIndex[ ] gIndices;
    uint count;
}

_InexactMatchResults _matchInexact(
    const _ExactMatchResults exactRes,
    _ConstUBlockArray uBlocks,
    _ConstGBlockArray gBlocks,
) {
    import std.array: uninitializedArray;
    import sumtype;
    import utils: unreachable;

    auto gIndices = uninitializedArray!(_GIndex[ ])(exactRes.uIndices.length);
    uint count;
    // TODO: Parallelize.
    foreach (i, ui; exactRes.uIndices) {
        const userOldText = uBlocks[ui].match!(
            (ref const tlu.DialogueBlock b) => b.oldText,
            (ref const tlu.UnrecognizedBlock _) => unreachable!string,
        );
        // TODO: Add a way to customize `maxDeviation`.
        const best = gIndices[i] = _findBestMatch(userOldText, gBlocks, exactRes.gIndices, .2);
        if (best != _GIndex.init)
            count++;
    }
    return _InexactMatchResults(gIndices, count);
}

void _mergeInexactResults(
    ref IndexedArray!(_GBlockInfo, _GIndex) gBlocksInfo,
    const(_UIndex)[ ] uIndices,
    ref _InexactMatchResults inexactRes,
) pure @nogc {
    if (!inexactRes.count)
        return;
    foreach (i, gi; inexactRes.gIndices)
        if (gi != _GIndex.init) {
            if (gBlocksInfo[gi].match != _UIndex.init) {
                // Multiple uBlocks matched the same gBlock; retain only the first match.
                inexactRes.count--;
            } else {
                gBlocksInfo[gi].match = cast()uIndices[i];
                gBlocksInfo[gi].matchedExactly = false;
            }
        }
}

IndexedArray!(bool, _UIndex) _createUMatchStatuses(
    const IndexedArray!(_GBlockInfo, _GIndex) gBlocksInfo,
    _UIndex n,
) pure {
    auto result = indexedArray!_UIndex(new bool[n + 1]);
    foreach (ref gInfo; gBlocksInfo.data)
        if (gInfo.match != _UIndex.init)
            result[gInfo.match] = true;
    result[n] = true; // Sentinel.
    return result;
}

Block[ ] _finalize(
    const IndexedArray!(_GBlockInfo, _GIndex) gBlocksInfo,
    size_t total,
    _UIndex uBlocksLength,
) pure {
    import std.array: uninitializedArray;
    import std.conv: emplace;

    auto result = uninitializedArray!(Block[ ])(total);
    size_t w = 0;

    const uMatchedSomehow = _createUMatchStatuses(gBlocksInfo, uBlocksLength);
    // Non-matched blocks at the top of the file.
    for (_UIndex i = 0; !uMatchedSomehow[i]; i++)
        emplace(&result[w++], NonMatchedBlock(cast(uint)i));

    foreach (ref gInfo; gBlocksInfo.data) {
        auto i = cast()gInfo.match;
        if (i == _UIndex.init)
            emplace(&result[w++], NewBlock.init);
        else {
            if (gInfo.matchedExactly)
                emplace(&result[w], MatchedBlock(cast(uint)i));
            else
                emplace(&result[w], InexactlyMatchedBlock(cast(uint)i));
            w++;
            // Bind non-matched blocks to the matched one preceeding them.
            while (!uMatchedSomehow[_UIndex(++i)])
                emplace(&result[w++], NonMatchedBlock(cast(uint)i));
        }
    }

    assert(w == total);
    return result;
}

Block[ ] _mergeBlocks(const(tlu.Block)[ ] _uBlocks, const(tlg.DialogueBlock)[ ] _gBlocks)
in {
    assert(_uBlocks.length <= uint.max);
    assert(_gBlocks.length <= uint.max);
}
do {
    auto uBlocks = indexedArray!_UIndex(_uBlocks);
    auto gBlocks = indexedArray!_GIndex(_gBlocks);

    auto aux = _prepare(gBlocks);
    const exactRes = _matchExact(aux, uBlocks);
    auto inexactRes = _matchInexact(exactRes, uBlocks, gBlocks);
    _mergeInexactResults(aux.gBlocksInfo, exactRes.uIndices, inexactRes);

    const nMatched = gBlocks.length - exactRes.gIndices.length;
    assert(nMatched == uBlocks.length - exactRes.uIndices.length);
    const nInexactlyMatched = inexactRes.count;
    const nNonMatched = uBlocks.length - nMatched - nInexactlyMatched;
    const nNew = gBlocks.length - nMatched - nInexactlyMatched;
    const total = nMatched + nInexactlyMatched + nNonMatched + nNew;

    return _finalize(aux.gBlocksInfo, total, uBlocks.length);
}

public Declarations merge(ref const tlu.Declarations uDecls, ref const tlg.Declarations gDecls) {
    return Declarations(_mergeBlocks(uDecls.blocks, gDecls.dialogueBlocks));
}
