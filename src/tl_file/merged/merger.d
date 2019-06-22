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

struct _GItemInfo {
    _UIndex match;
    _GIndex nextEponymous;
    bool matchedExactly = void; // Do not inspect this if `match` is not set.
}

struct _Aux {
    IndexedRange!(_GItemInfo[ ], _GIndex) gItemsInfo;
    _GIndex[string] oldTextMap;

    @disable this(this);
}

_Aux _prepare(GR)(GR gItems) pure if (_isGRange!GR) {
    import std.array: uninitializedArray;

    _Aux result = {
        indexedRange!_GIndex(
            uninitializedArray!(_GItemInfo[ ])(cast(size_t)gItems.length),
        ),
    };
    _GIndex i = gItems.length;
    foreach_reverse (ref b; gItems) {
        i--;
        result.gItemsInfo[i].match = _UIndex.init;
        if (auto p = b.value in result.oldTextMap) {
            result.gItemsInfo[i].nextEponymous = *p;
            *p = i;
        } else {
            result.gItemsInfo[i].nextEponymous = _GIndex.init;
            result.oldTextMap[b.value] = i;
        }
    }
    () @trusted { result.oldTextMap.rehash; }();
    return result;
}

struct _ExactMatchResults {
    _UIndex[ ] uUnmatched;
    _GIndex[ ] gUnmatched;
}

_GIndex[ ] _getUnmatchedGIndices(ref const IndexedRange!(_GItemInfo[ ], _GIndex) gItemsInfo)
pure {
    import std.algorithm.iteration: filter, map;
    import std.array: array;
    import std.range: enumerate;

    return
        gItemsInfo.data
        .enumerate!uint()
        .filter!(a => a.value.match == _UIndex.init)
        .map!(a => _GIndex(a.index))
        .array();
}

_ExactMatchResults _matchExact(UR)(ref _Aux aux, UR uItems) pure if (_isURange!UR) {
    import std.array: appender;

    auto uUnmatched = appender!(_UIndex[ ]);
    uUnmatched.reserve(32); // Just a random number, really.
    for (_UIndex ui = 0; ui < uItems.length; ui++) {
        if (!uItems[ui].valid)
            continue;
        if (auto p = uItems[ui].value in aux.oldTextMap) {
            const gi = *p;
            if (gi != _GIndex.init) {
                auto gInfo = (() @trusted => &aux.gItemsInfo[gi])();
                assert(gInfo.match == _UIndex.init);
                gInfo.match = ui;
                gInfo.matchedExactly = true;
                *p = gInfo.nextEponymous;
                continue;
            }
        }
        uUnmatched ~= ui;
    }

    return _ExactMatchResults(uUnmatched.data, _getUnmatchedGIndices(aux.gItemsInfo));
}

_GIndex _findBestMatch(GR)(
    string needle,
    GR gItems,
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
        const s = gItems[gi].value;
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
    UR uItems,
    GR gItems,
) if (_isURange!UR && _isGRange!GR) {
    import std.array: uninitializedArray;

    auto gIndices = uninitializedArray!(_GIndex[ ])(exactRes.uUnmatched.length);
    uint count;
    // TODO: Parallelize.
    foreach (i, ui; exactRes.uUnmatched) {
        assert(uItems[ui].valid);
        const userOldText = uItems[ui].value;
        // TODO: Add a way to customize `maxDeviation`.
        const best = gIndices[i] = _findBestMatch(userOldText, gItems, exactRes.gUnmatched, .2);
        if (best != _GIndex.init)
            count++;
    }
    return _InexactMatchResults(gIndices, count);
}

void _mergeInexactResults(
    ref IndexedRange!(_GItemInfo[ ], _GIndex) gItemsInfo,
    const(_UIndex)[ ] uIndices,
    ref _InexactMatchResults inexactRes,
) pure @nogc {
    if (!inexactRes.count)
        return;
    foreach (i, gi; inexactRes.gIndices)
        if (gi != _GIndex.init) {
            if (gItemsInfo[gi].match != _UIndex.init) {
                // Multiple uItems matched the same gItem; retain only the first match.
                inexactRes.count--;
            } else {
                gItemsInfo[gi].match = cast()uIndices[i];
                gItemsInfo[gi].matchedExactly = false;
            }
        }
}

IndexedRange!(bool[ ], _UIndex) _createUMatchStatuses(
    const IndexedRange!(_GItemInfo[ ], _GIndex) gItemsInfo,
    _UIndex n,
) pure {
    auto result = indexedRange!_UIndex(new bool[n + 1]);
    foreach (ref gInfo; gItemsInfo.data)
        if (gInfo.match != _UIndex.init)
            result[gInfo.match] = true;
    result[n] = true; // Sentinel.
    return result;
}

MergeResult[ ] _finalize(
    const IndexedRange!(_GItemInfo[ ], _GIndex) gItemsInfo,
    size_t total,
    _UIndex uItemsLength,
) pure {
    import std.array: uninitializedArray;
    import std.conv: emplace;

    auto result = uninitializedArray!(MergeResult[ ])(total);
    size_t w = 0;

    auto uMatchedSomehow = _createUMatchStatuses(gItemsInfo, uItemsLength);
    // Non-matched items at the top of the file.
    for (_UIndex i = 0; !uMatchedSomehow[i]; i++)
        emplace(&result[w++], NonMatched(cast(uint)i));

    foreach (ref gInfo; gItemsInfo.data) {
        auto i = cast()gInfo.match;
        if (i == _UIndex.init)
            emplace(&result[w++], New.init);
        else {
            if (gInfo.matchedExactly)
                emplace(&result[w], Matched(cast(uint)i));
            else
                emplace(&result[w], InexactlyMatched(cast(uint)i));
            w++;
            // Bind non-matched items to the matched one preceeding them.
            while (!uMatchedSomehow[_UIndex(++i)])
                emplace(&result[w++], NonMatched(cast(uint)i));
        }
    }

    assert(w == total);
    return result;
}

MergeResult[ ] _merge(UR, GR)(UR _uItems, GR _gItems)
if (_isTranslatableRange!(UR, size_t) && _isTranslatableRange!(GR, size_t))
in {
    assert(_uItems.length + _gItems.length <= uint.max);
}
out (result) {
    assert(result.length >= _gItems.length);
    assert(result.length <= _gItems.length + _uItems.length);
}
do {
    auto uItems = indexedRange!_UIndex(_uItems);
    auto gItems = indexedRange!_GIndex(_gItems);

    auto aux = _prepare(gItems);
    const exactRes = _matchExact(aux, uItems);
    auto inexactRes = _matchInexact(exactRes, uItems, gItems);
    _mergeInexactResults(aux.gItemsInfo, exactRes.uUnmatched, inexactRes);

    const nMatched = gItems.length - exactRes.gUnmatched.length;
    assert(nMatched == uItems.length - exactRes.uUnmatched.length);
    const nInexactlyMatched = inexactRes.count;
    const nNonMatched = uItems.length - nMatched - nInexactlyMatched;
    const nNew = gItems.length - nMatched - nInexactlyMatched;
    const total = nMatched + nInexactlyMatched + nNonMatched + nNew;

    return _finalize(aux.gItemsInfo, total, uItems.length);
}

public Results merge(ref const tlu.Declarations uDecls, ref const tlg.Declarations gDecls) {
    import std.algorithm.iteration: map;

    static struct String {
        enum valid = true;
        string value;
    }

    static struct UBlockString {
    pure @nogc:
        private const(tlu.Block)* _b;

        @property bool valid() const {
            import sumtype;

            return (*_b).match!(
                (ref const tlu.DialogueBlock _) => true,
                (ref const tlu.UnrecognizedBlock _) => false,
            );
        }

        @property string value() const {
            import sumtype;
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

    return Results(_merge(uBlocks, gBlocks), _merge(uStrings, gStrings));
}
