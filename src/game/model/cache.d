module game.model.cache;

/* PhysicsCache (former name: StateManager) holds many states, and knows when
 * to auto-save. Feed the StateManager with the current state all the time,
 * feed to function autoSave(). That will nop often.
 */

import std.algorithm;
import std.range;
import std.typecons;
import core.memory; // GC.collect();

import basics.help; // clone(T[]), a deep copy for arrays
import game.replay;
import game.model.state;
import hardware.tharsis;
import net.repdata;

import std.string; // format

enum DuringTurbo : bool { no = false, yes = true }

class PhysicsCache {

private:

    enum updatesMostFrequentPair = 10;
    enum updatesMultiplierNextPairIsSlowerBy = 5; // 10, 50, 250, 1250
    enum pairsToKeep = 4;

    GameState _zero;
    GameState _userState;
    GameState[2 * pairsToKeep] _auto;

    // For the user-triggered save (_user), remember the replay that was
    // correct by then. Otherwise, the user could restart, do something
    // deviating, and then load the user state that supposes the old,
    // differing replay.
    Replay _userReplay;

public:

    void dispose()
    {
        destroy(_zero);
        destroy(_userState);
        foreach (ref gs; _auto)
            destroy(gs);
        assert (! _auto[0].refCountedStore.isInitialized);
    }

    void saveZero(in GameState s) { _zero = s.clone(); }

    @property Phyu zeroStatePhyu() const {
        assert (_zero.refCountedStore.isInitialized);
        return _zero.update;
    }

    void saveUser(in GameState s, in Replay r)
    {
        _userState  = s.clone();
        assert (r);
        if (_userReplay is null
            || ! r.firstDifference(_userReplay).thisBeginsWithRhs)
            // r has info that _userReplay hasn't, store r
            _userReplay = r.clone();
    }

    bool userStateExists() const { return _userReplay !is null; }

    // Depending on mismatches between Nurse's replay and our saved replay,
    // some cached states must be invalidated. Fixes user-stateload desyncs.
    auto loadUser(in Replay nurseReplay)
    in {
        assert (userStateExists, "don't load if there is nothing to load");
        assert (nurseReplay, "need reference so I know what to invalidate");
    }
    body {
        auto deleteAfter = _userState.update;
        auto diff = _userReplay.firstDifference(nurseReplay);
        if (diff.mismatch && diff.firstDifferenceIfMismatch < deleteAfter)
            deleteAfter = diff.firstDifferenceIfMismatch;
        forgetAutoSavesOnAndAfter(deleteAfter);
        struct Ret {
            const(GameState) state;
            const(Replay) replay;
            FirstDifference loadedVsNurseReplay;
        }
        return Ret(_userState, _userReplay, diff);
    }

    const(GameState) loadBeforePhyu(in Phyu u)
    {
        GameState ret = _zero;
        foreach (gs; _auto)
            if (   gs.refCountedStore.isInitialized
                && gs.update < u && gs.update > ret.update)
                ret = gs;
        forgetAutoSavesOnAndAfter(u);
        return ret;
    }

    bool wouldAutoSave(
        in GameState s,
        in Phyu updTo,
        in DuringTurbo duringTurbo) const
    {
        immutable pair = duringTurbo ? 1 : 0;
        assert (pair >= 0 && pair < pairsToKeep);
        if (s.update == 0 || s.update % updateMultipleForPair(pair) != 0)
            return false;
        foreach (possible; pair .. pairsToKeep)
            // We save 2 states per update multiple. But when we want to update
            // 100 times, there is no need saving states after 10, 20, 30, ...
            // updates, we would only keep the states at 90 and 100, anyway.
            // And the state at 50 and 100, in a higher pair.
            if (s.update > updTo - 2 * updateMultipleForPair(possible)
                && s.update % updateMultipleForPair(possible) == 0)
                return true;
        return false;
    }

    void autoSave(in GameState s, in Phyu ultimatelyTo)
    {
        if (! wouldAutoSave(s, ultimatelyTo, DuringTurbo.no))
            return;
        // Potentially push older auto-saved states down the hierarchy.
        // First, if it's time to copy a frequent state into a less frequent
        // state, make these copies. Start with least frequent copying the
        // second-to-least freqent.
        // After copying the internal states like that, save s into the most
        // frequently updated pair. The most frequently updated pair has
        // array indices 0 and 1. The next one has array indices 2 and 3, ...
        for (int pair = pairsToKeep - 1; pair >= 0; --pair) {
            immutable int umfp = updateMultipleForPair(pair);
            if (s.update % umfp == 0) {
                int whichOfPair = (s.update / umfp) % 2;
                if (pair > 0)
                    // Make a shallow copy of the more-frequently-hit state:
                    // We treat states inside PhysicsCache like immutable.
                    // Only clone when we return to outside of PhysicsCache.
                    _auto[2*pair + whichOfPair] = _auto[2*(pair-1)];
                else
                    // Make a hard copy of the current state.
                    _auto[0 + whichOfPair] = s.clone();
            }
        }
    }

private:
    void forgetAutoSavesOnAndAfter(in Phyu u)
    {
        foreach (ref GameState gs; _auto)
            if (gs.refCountedStore.isInitialized && gs.update >= u)
                destroy(gs);
    }

    int updateMultipleForPair(in int pair) const pure
    {
        assert (pair >= 0 && pair < pairsToKeep);
        int ret = updatesMostFrequentPair;
        foreach (i; 0 .. pair)
            ret *= updatesMultiplierNextPairIsSlowerBy;
        return ret;
    }
}
// end class StateManager
