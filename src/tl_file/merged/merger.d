module tl_file.merged.merger;

import std.range.primitives: ElementType;
import std.traits: ifTestable, Select;
import std.typecons: Typedef;

import indexed_range;
import tl_file.merged.model;
import tlg = tl_file.generated.model;
import tlu = tl_file.user.model;

private nothrow @safe:

alias _UIndex = Typedef!(uint, uint.max, q{tl_file.merged.merger._UIndex});
alias _GIndex = Typedef!(uint, uint.max, q{tl_file.merged.merger._GIndex});

static assert(!is(_UIndex == _GIndex));

enum _isTranslatable(T) = ifTestable!(typeof(T.valid)) && is(typeof(T.value): string);

enum _isCTTranslatable(T) =
    Select!(__traits(compiles, () => T.valid), T.valid, false) && is(typeof(T.value): string);

enum _isTranslatableRange(R, I) =
    _isTranslatable!(ElementType!R) && is(typeof(R.init[I.init]): ElementType!R);

enum _isCTTranslatableRange(R, I) =
    _isCTTranslatable!(ElementType!R) && is(typeof(R.init[I.init]): ElementType!R);

enum _isURange(R) = _isTranslatableRange!(R, _UIndex);
enum _isGRange(R) = _isCTTranslatableRange!(R, _GIndex);

pure @nogc unittest {
    static struct RT {
        bool valid;
        string value;
    }

    static struct CT {
        enum valid = true;
        string value;
    }

    static assert(_isTranslatableRange!(const(RT)[ ], uint));
    static assert(_isTranslatableRange!(const(CT)[ ], uint));
    static assert(_isTranslatableRange!(IndexedRange!(const(RT)[ ], _UIndex), _UIndex));
    static assert(_isTranslatableRange!(IndexedRange!(const(CT)[ ], _UIndex), _UIndex));
    static assert(_isTranslatableRange!(IndexedRange!(const(RT)[ ], _GIndex), _GIndex));
    static assert(_isTranslatableRange!(IndexedRange!(const(CT)[ ], _GIndex), _GIndex));
    static assert(_isCTTranslatableRange!(IndexedRange!(const(CT)[ ], _UIndex), _UIndex));
    static assert(_isCTTranslatableRange!(IndexedRange!(const(CT)[ ], _GIndex), _GIndex));
}

struct _GBlockInfo {
    _UIndex match;
    _GIndex nextEponymous;
    bool matchedExactly = void; // Do not inspect this if `match` is not set.
}

struct _Aux {
    IndexedRange!(_GBlockInfo[ ], _GIndex) gBlocksInfo;
    _GIndex[string] oldTextMap;

    @disable this(this);
}

_Aux _prepare(GR)(GR gBlocks) pure if (_isGRange!GR) {
    import std.array: uninitializedArray;

    _Aux result = {
        indexedRange!_GIndex(
            uninitializedArray!(_GBlockInfo[ ])(cast(size_t)gBlocks.length),
        ),
    };
    _GIndex i = gBlocks.length;
    foreach_reverse (ref b; gBlocks) {
        i--;
        result.gBlocksInfo[i].match = _UIndex.init;
        if (auto p = b.value in result.oldTextMap) {
            result.gBlocksInfo[i].nextEponymous = *p;
            *p = i;
        } else {
            result.gBlocksInfo[i].nextEponymous = _GIndex.init;
            result.oldTextMap[b.value] = i;
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

_GIndex[ ] _getUnmatchedGIndices(ref const IndexedRange!(_GBlockInfo[ ], _GIndex) gBlocksInfo)
pure {
    import std.algorithm.iteration: filter, map;
    import std.array: array;
    import std.range: enumerate;

    return
        gBlocksInfo.data
        .enumerate!uint()
        .filter!(a => a.value.match == _UIndex.init)
        .map!(a => _GIndex(a.index))
        .array();
}

_ExactMatchResults _matchExact(UR)(ref _Aux aux, UR uBlocks) pure if (_isURange!UR) {
    import std.array: appender;

    auto uUnmatched = appender!(_UIndex[ ]);
    uUnmatched.reserve(32); // Just a random number, really.
    for (_UIndex ui = 0; ui < uBlocks.length; ui++) {
        if (!uBlocks[ui].valid)
            continue;
        if (auto p = uBlocks[ui].value in aux.oldTextMap) {
            const gi = *p;
            if (gi != _GIndex.init) {
                auto gInfo = (() @trusted => &aux.gBlocksInfo[gi])();
                assert(gInfo.match == _UIndex.init);
                gInfo.match = ui;
                gInfo.matchedExactly = true;
                *p = gInfo.nextEponymous;
                continue;
            }
        }
        uUnmatched ~= ui;
    }

    return _ExactMatchResults(uUnmatched.data, _getUnmatchedGIndices(aux.gBlocksInfo));
}

_GIndex _findBestMatch(GR)(
    string needle,
    GR gBlocks,
    const(_GIndex)[ ] gIndices,
    double maxDeviation,
) @nogc if (_isGRange!GR) {
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
        const s = gBlocks[gi].value;
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

_InexactMatchResults _matchInexact(UR, GR)(
    const _ExactMatchResults exactRes,
    UR uBlocks,
    GR gBlocks,
) if (_isURange!UR && _isGRange!GR) {
    import std.array: uninitializedArray;

    auto gIndices = uninitializedArray!(_GIndex[ ])(exactRes.uIndices.length);
    uint count;
    // TODO: Parallelize.
    foreach (i, ui; exactRes.uIndices) {
        assert(uBlocks[ui].valid);
        const userOldText = uBlocks[ui].value;
        // TODO: Add a way to customize `maxDeviation`.
        const best = gIndices[i] = _findBestMatch(userOldText, gBlocks, exactRes.gIndices, .2);
        if (best != _GIndex.init)
            count++;
    }
    return _InexactMatchResults(gIndices, count);
}

void _mergeInexactResults(
    ref IndexedRange!(_GBlockInfo[ ], _GIndex) gBlocksInfo,
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

IndexedRange!(bool[ ], _UIndex) _createUMatchStatuses(
    const IndexedRange!(_GBlockInfo[ ], _GIndex) gBlocksInfo,
    _UIndex n,
) pure {
    auto result = indexedRange!_UIndex(new bool[n + 1]);
    foreach (ref gInfo; gBlocksInfo.data)
        if (gInfo.match != _UIndex.init)
            result[gInfo.match] = true;
    result[n] = true; // Sentinel.
    return result;
}

Block[ ] _finalize(
    const IndexedRange!(_GBlockInfo[ ], _GIndex) gBlocksInfo,
    size_t total,
    _UIndex uBlocksLength,
) pure {
    import std.array: uninitializedArray;
    import std.conv: emplace;

    auto result = uninitializedArray!(Block[ ])(total);
    size_t w = 0;

    auto uMatchedSomehow = _createUMatchStatuses(gBlocksInfo, uBlocksLength);
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

Block[ ] _merge(UR, GR)(UR _uBlocks, GR _gBlocks)
if (_isTranslatableRange!(UR, size_t) && _isTranslatableRange!(GR, size_t))
in {
    assert(_uBlocks.length <= uint.max);
    assert(_gBlocks.length <= uint.max);
}
do {
    auto uBlocks = indexedRange!_UIndex(_uBlocks);
    auto gBlocks = indexedRange!_GIndex(_gBlocks);

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
    import std.algorithm.iteration: map;
    import sumtype;

    static struct String {
        enum valid = true;
        string value;
    }

    static struct UBlockString {
    pure @nogc:
        private const(tlu.Block)* _b;

        @property bool valid() const {
            return (*_b).match!(
                (ref const tlu.DialogueBlock _) => true,
                (ref const tlu.UnrecognizedBlock _) => false,
            );
        }

        @property string value() const {
            import utils: unreachable;

            return (*_b).match!(
                (ref const tlu.DialogueBlock b) => b.oldText,
                (ref const tlu.UnrecognizedBlock _) => unreachable!string,
            );
        }
    }

    auto uBlocks = uDecls.blocks.map!((ref b) @trusted => UBlockString(&b));
    auto gBlocks = gDecls.dialogueBlocks.map!((ref b) => String(b.oldText));
    auto uStrings = uDecls.plainStrings.map!((ref b) => String(b.oldText));
    auto gStrings = gDecls.plainStrings.map!((ref b) => String(b.oldText));

    return Declarations(_merge(uBlocks, gBlocks), _merge(uStrings, gStrings));
}
