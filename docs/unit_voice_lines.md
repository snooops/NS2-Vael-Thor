# Vael'Thor Units – Voice Lines (Recording Script)

Companion to `commander_voice_lines.md`. Every caste has its own voice. The common ground:
soldiers of the Empire do not complain, do not joke and do not fear death; the Matrix returns
them. They speak in short, clipped statements, never questions. They refer to the commander as
**"the Archon"** (the in-game directive messages already say "The Archon decrees").

File names in brackets; record every variant. Takes stay under ~2 seconds unless noted.
The same `process.sh` chain can be used, with per-caste tweaks listed under each voice direction.

---

## Vanguard Legionnaire

Core infantry. Disciplined, drilled, a soldier among thousands. Firm, mid-pitch, almost
military-parade cadence. Effects: standard chain, a bit less reverb (radio-helmet feel:
`reverb 15 40 50`).

**Spawn / synthesized** `[vt_vanguard_spawn_01-03]`
1. "Legionnaire, synthesized. Ready to serve."
2. "Returned from the Matrix. For Vael'Thor."
3. "The Legion stands."

**Acknowledge order** `[vt_vanguard_ack_01-04]`
1. "By the Archon's will."
2. "Understood."
3. "It will be done."
4. "Moving."

**Order complete** `[vt_vanguard_done_01-02]`
1. "Objective secured."
2. "Done. Awaiting orders."

**Request orders** `[vt_vanguard_req_orders_01-02]`
1. "Archon. Orders."
2. "Awaiting your command."

**Request shields (Shield Pulse)** `[vt_vanguard_req_shield_01-02]`
1. "Shields failing. Require a pulse."
2. "Psi shield down. Support."

**Request weapon** `[vt_vanguard_req_weapon_01]`
1. "Requesting arms."

**Follow me** `[vt_vanguard_follow_01-02]`
1. "On me."
2. "Legion, follow."

**Let's move** `[vt_vanguard_move_01-02]`
1. "Advance."
2. "Forward. For the Empire."

**Covering** `[vt_vanguard_cover_01-02]`
1. "I have you covered."
2. "Your flank is guarded."

**Enemy spotted** `[vt_vanguard_spotted_01-03]`
1. "Hostiles sighted."
2. "Contact. Vermin ahead."
3. "The enemy is here."

**Structure needed / build** `[vt_vanguard_build_01]`
1. "Raising the structure."

**Taunt** `[vt_vanguard_taunt_01-03]`
1. "Kneel, or burn."
2. "Your world is ours."
3. "The Empire is eternal. You are not."

**Kill** `[vt_vanguard_kill_01-03]`
1. "Target purged."
2. "Cleansed."
3. "One less."

**Under fire** `[vt_vanguard_hit_01-02]`
1. "Taking fire."
2. "Engaged."

**Energy depleted (carbine)** `[vt_vanguard_energy_01]`
1. "Carbine drained. Need a Pylon."

**Module: Phase Dash** `[vt_vanguard_dash_01]` – optional grunt/short exhale

**Module: Shield Overdrive** `[vt_vanguard_overdrive_01-02]`
1. "Overdrive!"
2. "Full power!"

**Death** `[vt_vanguard_death_01-03]` – short, controlled, no screaming
1. "For… Vael'Thor…"
2. "The Matrix… will…"
3. (sharp breath, cut off)

---

## Infiltrator

Scout and assassin of the psionic order. Quiet, close to the microphone, almost whispered,
slow and cold. Never raises the voice. Effects: no octave sub-layer, stronger shimmer
(`volume=0.4`), very short reverb.

**Spawn** `[vt_infiltrator_spawn_01-03]`
1. "Infiltrator. In the shadows."
2. "Unseen. Unheard. Ready."
3. "The hunt begins."

**Acknowledge** `[vt_infiltrator_ack_01-03]`
1. "As the Archon wills."
2. "Silently."
3. "Understood."

**Order complete** `[vt_infiltrator_done_01]`
1. "It is done. No one saw."

**Cloak on** `[vt_infiltrator_cloak_01-02]`
1. "Vanishing."
2. "They will not see me."

**Cloak broken / energy empty** `[vt_infiltrator_decloak_01-02]`
1. "Cloak failing."
2. "I am exposed."

**Hack pulse (Neural Override)** `[vt_infiltrator_hack_01-02]`
1. "Their machines obey me now."
2. "Override."

**Enemy spotted / scouting report** `[vt_infiltrator_spotted_01-03]`
1. "Enemy presence detected."
2. "I see them. They do not see me."
3. "Their nest is here. Mark it."

**Kill (blade)** `[vt_infiltrator_kill_01-03]`
1. "Silenced."
2. "From the shadows."
3. "Quietly."

**Request shields** `[vt_infiltrator_req_shield_01]`
1. "Shield lost. I need support."

**Taunt** `[vt_infiltrator_taunt_01-02]`
1. "You never saw me."
2. "Fear the silence."

**Death** `[vt_infiltrator_death_01-02]`
1. (sharp exhale)
2. "Seen… at last…"

---

## Subject (Bio-Construct)

Engineered war-beast. Not a speaker – a conditioned weapon. Mostly vocalizations: growls,
roars, heavy breathing. The few words it has are broken, conditioned phrases, as if hammered
into it. Effects: pitch much lower (`pitch=0.75`), octave layer loud (`volume=0.45`),
drop the shimmer, add distortion if wanted.

**Spawn** `[vt_subject_spawn_01-03]`
1. (deep roar)
2. "Subject… awake."
3. "Obey. Kill. Obey."

**Acknowledge** `[vt_subject_ack_01-03]`
1. "Obey."
2. (short growl)
3. "Yes… Archon."

**Attack / charge** `[vt_subject_charge_01-03]`
1. (roar)
2. "KILL."
3. "Tear… them…"

**Dodge / double jump** `[vt_subject_dodge_01-02]` – short grunts

**Hit by enemy** `[vt_subject_hit_01-03]` – growls of pain/anger, 0.5–1 s

**Kill** `[vt_subject_kill_01-02]`
1. (satisfied snarl)
2. "Broken."

**Enemy spotted** `[vt_subject_spotted_01-02]`
1. (sniffing, then growl)
2. "Prey."

**Taunt** `[vt_subject_taunt_01-02]`
1. (long roar, up to 3 s)
2. "Come… to me…"

**Death** `[vt_subject_death_01-02]` – long dying roar fading into a breath, up to 3 s

---

## Praetor

Heavy elite, the Empire's champion. Slow, enormously confident, almost bored by the enemy.
Deeper and fuller than the Vanguard; speaks like nobility. Effects: `pitch=0.84`, octave
layer `volume=0.3`, big hall reverb as for the commander.

**Spawn** `[vt_praetor_spawn_01-03]`
1. "The Praetor has arrived."
2. "I walk in the Archon's name."
3. "Let them come."

**Acknowledge** `[vt_praetor_ack_01-03]`
1. "As decreed."
2. "My will is the Archon's."
3. "It shall be so."

**Order complete** `[vt_praetor_done_01]`
1. "They are no more."

**Gatling-Plasma firing** `[vt_praetor_fire_01-02]`
1. "Burn!"
2. "Feel the Empire's fire!"

**Homing missiles (lock-on)** `[vt_praetor_lock_01-02]`
1. "Target locked."
2. "There is no escape."

**Teleport Dash** `[vt_praetor_dash_01]`
1. "Step aside."

**Enemy spotted** `[vt_praetor_spotted_01-02]`
1. "Vermin. How dull."
2. "Ah. Something to kill."

**Follow me** `[vt_praetor_follow_01-02]`
1. "Legion. Behind me."
2. "Follow the Praetor."

**Kill** `[vt_praetor_kill_01-03]`
1. "Insignificant."
2. "Next."
3. "As expected."

**Under fire** `[vt_praetor_hit_01-02]`
1. "You dare?"
2. "A scratch."

**Request shields** `[vt_praetor_req_shield_01]`
1. "Archon. My shields."

**Taunt** `[vt_praetor_taunt_01-03]`
1. "Your extinction is a formality."
2. "Kneel before the Empire."
3. "I have slain greater than you."

**Death** `[vt_praetor_death_01-02]`
1. "Impossible…"
2. "The Empire… endures…"

---

## Artificer

Six-legged Crucible drone foundry. A thinker, not a fighter: precise, analytical,
slightly mechanical. Calm even under fire. Effects: standard chain plus a light robotic
ring-mod or flanger, little reverb.

**Spawn** `[vt_artificer_spawn_01-02]`
1. "Artificer online. The Crucible burns."
2. "Foundry active. Awaiting materials."

**Acknowledge** `[vt_artificer_ack_01-03]`
1. "Calculated."
2. "Processing. Complying."
3. "As the Archon designs."

**Drone launched – Wasp** `[vt_artificer_wasp_01]`
1. "Wasp deployed."

**Drone launched – Lancer** `[vt_artificer_lancer_01]`
1. "Lancer deployed."

**Drone launched – Sapper** `[vt_artificer_sapper_01]`
1. "Sapper armed."

**Directive: Hunt** `[vt_artificer_hunt_01]`
1. "Drones, hunt."

**Directive: Escort** `[vt_artificer_escort_01]`
1. "Drones, protect."

**Directive: Siege** `[vt_artificer_siege_01]`
1. "Drones, dismantle their structures."

**Directive: Focus / Swarm Command** `[vt_artificer_focus_01-02]`
1. "All drones. That target."
2. "Swarm. Converge."

**Drone lost** `[vt_artificer_dronelost_01-02]`
1. "Drone lost. Replacing."
2. "Unit destroyed. Acceptable."

**Under attack** `[vt_artificer_hit_01-02]`
1. "Foundry under attack."
2. "Hull damage. Recalculating."

**Kill** `[vt_artificer_kill_01]`
1. "Target dismantled."

**Death** `[vt_artificer_death_01-02]`
1. "Crucible… failing…"
2. (mechanical wind-down, no words)

---

## Drones (Wasp / Lancer / Sapper)

No speech. Short synthetic sounds, made in post (not recorded): a 0.2 s "chirp" on
launch, a falling tone on destruction, and for the Sapper a rising whine 1 s before
detonation. If you want a voice: one whispered word through heavy ring-mod.

**Sapper detonating** `[vt_sapper_detonate_01]`
1. "Detonate." (optional, whispered + heavy ring-mod)

---

## Shared lines (any caste, generic)

Use when a caste has no specific line, recorded in the Vanguard voice.

**Yes / Acknowledged** `[vt_shared_yes_01-02]`
1. "Acknowledged."
2. "Yes, Archon."

**No / Negative** `[vt_shared_no_01-02]`
1. "Negative."
2. "Not possible."

**Thanks (after shield pulse / heal)** `[vt_shared_thanks_01-02]`
1. "Shields restored."
2. "The Archon provides."

**Teleport via Nexus Gate** `[vt_shared_gate_01-02]`
1. "Through the Gate."
2. "Translocating."

**Directive heard (Requisition / Relentless / Iron)** `[vt_shared_directive_01-03]`
1. "The Archon has spoken!"
2. "For the Empire!"
3. "Hold the line!"
