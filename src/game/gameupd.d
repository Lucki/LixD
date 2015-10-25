module game.gameupd;

/* Updating the game physics. This usually happens 15 times per second.
 * With fast forward, it's called more often; during pause, never.
 */

import basics.cmdargs : Runmode;
import basics.nettypes;
import game;
import graphic.gadget;

package void
syncNetworkThenUpdateOnce(Game game)
{
    game.finalizeInputBeforeUpdate();
    game.updateOnceWithoutSyncingNetwork();
}



package void
updateOnceWithoutSyncingNetwork(Game game)
{
    assert (game.cs);
    ++game.cs.update;
    game.evaluateReplayData();
    game.updateClock();
    game.spawnLixxiesFromHatches();
    game.updateNuke();
    game.updateLixxies();
    game.updateOnceGadgets();

    if (game.runmode == Runmode.INTERACTIVE) {
        assert (game.stateManager);
        game.stateManager.calcSaveAuto(game.cs);
    }
}



private:

void
finalizeInputBeforeUpdate(Game game)
{
    // put spawn interval into replay
    // get network data and put it into replay vector
}



void
evaluateReplayData(Game game)
{
    assert (game.replay);
    auto dataSlice = game.replay.getDataForUpdate(game.cs.update);

    // Evaluating replay data, which carries out mere assignments, should be
    // independent of player order. Nonetheless, out of paranoia, we do it
    // in the order of players first, only then in the order of 'data'.
    foreach (tribe; game.cs.tribes)
        foreach (ref const(ReplayData) data; dataSlice)
            if (auto master = tribe.getMasterWithNumber(data.player))
                game.updateOneData(tribe, master, data);
}




void
updateOneData(
    Game game,
    Tribe t,
    in Tribe.Master* m,
    ref const(ReplayData) i
) {
    immutable upd = game.cs.update;
/+
    if (i.action == ReplayData.SPAWNINT) {
        const int spint = i->what;
        if (spint >= t.spawnint_fast && spint <= t.spawnint_slow) {
            t.spawnint = spint;
            if (&t == trlo) pan.spawnint_cur.set_spawnint(t.spawnint);
        }
    }
    else if (i->action == Replay::NUKE) {
        if (!t.nuke) {
            t.lix_hatch = 0;
            t.nuke      = true;
            if (&t == trlo) {
                pan.nuke_single.set_on();
                pan.nuke_multi .set_on();
            }
            effect.add_sound(upd, t, 0, Sound::NUKE);
        }
    }
    else if (i->action == Replay::ASSIGN
          || i->action == Replay::ASSIGN_LEFT
          || i->action == Replay::ASSIGN_RIGHT) {
        if (!m) return;

        Level::SkIt psk = t.skills.find(static_cast <LixEn::Ac> (i->skill));
        if (psk == t.skills.end())
            // should never happen
            return;

        if (i->what < t.lixvec.size()) {
            Lixxie& lix = t.lixvec[i->what];
            // false: Do not respect the user's options like
            // disabling the multiple builder feature
            if (lix.get_priority(psk->first, false) > 1 && psk->second != 0
             && ! (lix.get_dir() ==  1 && i->action == Replay::ASSIGN_LEFT)
             && ! (lix.get_dir() == -1 && i->action == Replay::ASSIGN_RIGHT)
            ) {
                ++(t.skills_used);
                if (psk->second != LixEn::infinity) --(psk->second);
                lix.evaluate_click(psk->first);
                // Draw arrow if necessary, read arrow.h/effect.h for info
                if ((useR->arrows_replay  && replaying)
                 || (useR->arrows_network && (multiplayer && ! replaying)
                                          && m != malo)) {
                    Arrow arr(map, t.style, lix.get_ex(), lix.get_ey(),
                        psk->first, upd, i->what);
                    effect.add_arrow(upd, t, i->what, arr);
                }
                Sound::Id snd = Lixxie::get_ac_func(psk->first).sound_assign;
                if (m == malo)
                    effect.add_sound      (upd, t, i->what, snd);
                else if (&t == trlo)
                    effect.add_sound_quiet(upd, t, i->what, snd);
            }
        }
        // we will reset all skill numbers on the panel anyway after
        // this function has finished
    }
+/
}
// end updateOneData()



void updateClock(Game game) { with (game)
{
    if (level.seconds <= 0)
        return;

    if (cs.clockIsRunning && cs.clock > 0)
        --cs.clock;

    /+
    // Im Multiplayer:
    // Nuke durch die letzten Sekunden der Uhr. Dies loest
    // kein Netzwerk-Paket aus! Alle Spieler werden jeweils lokal genukt.
    // Dies fuehrt dennoch bei allen zum gleichen Spielverlauf, da jeder
    // Spieler das Zeitsetzungs-Paket zum gleichen Update erhalten.
    // Wir muessen dies nach dem Replayauswerten machen, um festzustellen,
    // dass noch kein Nuke-Ereignis im Replay ist.
    if (multiplayer && cs.clock_running &&
     cs.clock <= (unsigned long) Lixxie::updates_for_bomb)
     for (Tribe::It tr = cs.tribes.begin(); tr != cs.tribes.end(); ++tr) {
        if (!tr->nuke) {
            // Paket anfertigen
            Replay::Data  data;
            data.update = upd;
            data.player = tr->masters.begin()->number;
            data.action = Replay::NUKE;
            replay.add(data);
            // Und sofort ausfuehren: Replay wurde ja schon ausgewertet
            tr->lix_hatch = 0;
            tr->nuke           = true;
            if (&*tr == trlo) {
                pan.nuke_single.set_on();
                pan.nuke_multi .set_on();
            }
            effect.add_sound(upd, *tr, 0, Sound::NUKE);
        }
    }
    // Singleplayer:
    // Upon running out of time entirely, shut all exits
    if (! multiplayer && cs.clock_running && cs.clock == 0
     && ! cs.goals_locked) {
        cs.goals_locked = true;
        effect.add_sound(upd, *trlo, 0, Sound::OVERTIME);
    }
    // Ebenfalls etwas Uhriges: Gibt es Spieler mit geretteten Lixen,
    // die aber keine Lixen mehr im Spiel haben oder haben werden? Dann
    // wird die Nachspielzeit angesetzt. Falls aber alle Spieler schon
    // genukt sind, dann setzen wir die Zeit nicht an, weil sie vermutlich
    // gerade schon ausgelaufen ist.
    if (!cs.clock_running)
     for (Tribe::CIt i = cs.tribes.begin(); i != cs.tribes.end(); ++i)
     if (i->lix_saved > 0 && ! i->get_still_playing()) {
        // Suche nach Ungenuktem
        for (Tribe::CIt j = cs.tribes.begin(); j != cs.tribes.end(); ++j)
         if (! j->nuke && j->get_still_playing()) {
            cs.clock_running = true;
            // Damit die Meldung nicht mehrmals kommt bei hoher Netzlast
            effect.add_overtime(upd, *i, cs.clock);
            break;
        }
        break;
    }
    // Warnsounds
    if (cs.clock_running
     && cs.clock >  0
     && cs.clock != (unsigned long) level.seconds
                                  * gloB->updates_per_second
     && cs.clock <= (unsigned long) gloB->updates_per_second * 15
     && cs.clock % gloB->updates_per_second == 0)
     for (Tribe::CIt i = cs.tribes.begin(); i != cs.tribes.end(); ++i)
     if (!i->lixvec.empty()) {
        // The 0 goes where usually a lixvec ID would go, because this
        // is one of the very few sounds that isn't attached to a lixvec.
        effect.add_sound(upd, *trlo, 0, Sound::CLOCK);
        break;
    }
    +/
}}
// end with (game); end updateClock()



void
spawnLixxiesFromHatches(Game game)
{
    /+
    for (Tribe::It t = cs.tribes.begin(); t != cs.tribes.end(); ++t)
    {
        const int position = replay.get_permu()[t - cs.tribes.begin()];
        // Create new Lixxie if necessary
        if (t->lix_hatch != 0 && upd >= 60 &&
         (t->update_hatch == 0 || upd >= t->update_hatch + t->spawnint))
            // sometimes, spawnint can be more than 60. In this case, it's fine
            // to spawn earlier than usual if we haven't spawned anything at
            // all yet, this is the first || criterion.
        {
            t->update_hatch = upd;
            const EdGraphic& h = hatches[t->hatch_next];
            Lixxie& newlix = t->lixvec[level.initial - t->lix_hatch];
            newlix = Lixxie(&*t,
             h.get_x() + h.get_object()->get_trigger_x(),
             h.get_y() + h.get_object()->get_trigger_y());
            --t->lix_hatch;
            ++t->lix_out;

            // Lixes start walking to the left instead of right?
            bool turn_new_lix = false;
            if (h.get_rotation()) turn_new_lix = true;
            // This extra turning solution here is necessary to make
            // some L1 and ONML two-player levels better playable.
            if (hatches.size() < cs.tribes.size()
             && (position / hatches.size()) % 2 == 1) turn_new_lix = true;

            if (turn_new_lix) {
                newlix.turn();
                newlix.move_ahead();
            }

            // It's the next hatches turn
            t->hatch_next += cs.tribes.size();
            t->hatch_next %= hatches.size();
        }
    }
    +/
}
// end spawnLixxiesFromHatches()



void
updateNuke(Game game)
{
    /+
    // Instant nuke should not display a countdown fuse in any frame.
    for (Tribe::It t = cs.tribes.begin(); t != cs.tribes.end(); ++t) {
        // Assign exploders in case of nuke
        if (t->nuke == true)
         for (LixIt i = t->lixvec.begin(); i != t->lixvec.end(); ++i) {
            if (i->get_updates_since_bomb() == 0 && ! i->get_leaving()) {
                i->inc_updates_since_bomb();
                // Which exploder shall be assigned?
                if (cs.tribes.size() > 1) {
                    i->set_exploder_knockback();
                }
                else for (Level::CSkIt itr =  t->skills.begin();
                                       itr != t->skills.end(); ++itr
                ) {
                    if (itr->first == LixEn::EXPLODER2) {
                        i->set_exploder_knockback();
                        break;
                    }
                }
                break;
            }
        }
    }
    +/
}



void
updateLixxies(Game game)
{
    /+
    // Lixen updaten
    UpdateArgs ua(cs);

    // Erster Durchlauf: Nur die Arbeitstiere bearbeiten und markieren!
    for (Tribe::It t = cs.tribes.begin(); t != cs.tribes.end(); ++t) {
        for (LixIt i = t->lixvec.begin(); i != t->lixvec.end(); ++i) {
            if (i->get_ac() > LixEn::WALKER) {
                ua.id = i - t->lixvec.begin();
                i->mark();
                update_lix(*i, ua);
            }
            // Sonst eine vorhandene Markierung ggf. entfernen
            else i->unmark();
        }
    }
    // Zweiter Durchlauf: Unmarkierte bearbeiten
    for (Tribe::It t = cs.tribes.begin(); t != cs.tribes.end(); ++t) {
        for (LixIt i = t->lixvec.begin(); i != t->lixvec.end(); ++i) {
            if (!i->get_mark()) {
                ua.id = i - t->lixvec.begin();
                update_lix(*i, ua);
            }
        }
    }
    // Third pass (if necessary): finally becoming flingers
    if (Lixxie::get_any_new_flingers()) {
        for (Tribe::It t = cs.tribes.begin(); t != cs.tribes.end(); ++t)
         for (LixIt i = t->lixvec.begin(); i != t->lixvec.end(); ++i) {
            if (i->get_fling_new()) finally_fling(*i);
        }
    }
    +/
}



void
updateOnceGadgets(Game game) {
    with (game)
    with (game.cs)
{
    // Animate after we had the traps eat lixes. Eating a lix sets a flag
    // in the trap to run through the animation, showing the first killing
    // frame after this next call to animate(). Physics depend on this anim.
    foreach (hatch; hatches)
        hatch.animate(effect, update);

    foreachGadget((Gadget g) {
        g.animate();
    });
}}
// end with (game.cs), end update_once()
