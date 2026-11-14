# Sound effects

Drop sound files here with these names and they play in the game. You don't
need to change any code. Any name without a file stays silent.

- Use `.wav` for short sounds (`.ogg` and `.mp3` work too).
- For variety, number the takes: `footstep_1.wav`, `footstep_2.wav`, `footstep_3.wav`...
  The game picks one at random each time and nudges its pitch a little.

## Player
| File | When |
|---|---|
| `player/footstep` | Each step: frames 1 and 3 of the walk animation (Player → Sound → Footstep Frames) |

## Tools
| File | When |
|---|---|
| `tools/set_down` | Putting a tool down (right click or Q) |
| `tools/pick_up` | Picking a tool up |
| `tools/holy_water_throw` | Throwing a flask |
| `tools/holy_water_splash` | The flask landing (in the world, at the splash) |

## UI
| File | When |
|---|---|
| `ui/select_slot` | Changing toolbar slot (1-9, mouse wheel) |
| `ui/blocked` | Trying to place somewhere you can't (the red flash) |

## House objects (defaults for every switchable)
Each object scene can override these in the Inspector, under **Sound**:
Change Sound, Change Back Sound, and Loop Sound (loops while it's on, lit or rocking).

| File | When |
|---|---|
| `objects/switch_on` / `objects/switch_off` | `_on` things: sinks, tubs |
| `objects/knock_over` / `objects/set_right` | `_knocked` things: book stacks |
| `objects/break` | `_broken` things: jars, the vanity |
| `objects/start_playing` | `_played` things: the rocking chair |
| `objects/light_fire` / `objects/put_out_fire` | `_lit` things: fireplaces, candles |

## Ghost
| File | When |
|---|---|
| `ghost/appear` | The ghost appears (after breaking something) |
| `ghost/hunt_start` | A hunt starts (heard everywhere) |

## Ritual
| File | When |
|---|---|
| `ritual/start` | Starting the ritual with a potion |
| `ritual/success` | The right potion: the ghost evaporates (in the world, at the ghost) |
| `ritual/fail` | The wrong potion: the ghost attacks (in the world, at the ghost) |
