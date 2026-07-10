# Technical Design: TV Long-Press Seek Acceleration

## Current Behavior

`TvPlayerRoute` performs an immediate short seek, waits 250ms, then calls `TvPlayerViewModel.seekByDirection` every 100ms. `TvSeekController` maps hold duration to a seek delta and separately calculates the center overlay display time.

The current stages are 12 seconds per tick followed by 18 seconds per tick after roughly 5 seconds. The overlay seconds ones digit already advances from physical hold time instead of the accelerated real target.

## Selected Timing Model

Keep the scheduler unchanged and update `TvSeekController.computeDeltaSeconds` to use total physical hold duration:

| Physical hold duration | Delta per call |
|---|---:|
| `< 250ms` | 10 seconds |
| `250ms <= hold < 4,000ms` | 12 seconds |
| `hold >= 4,000ms` | 22 seconds |

The acceleration boundary is measured from the original key-down time, so the user feels the gear change at approximately four physical seconds rather than four seconds after the 250ms guard interval.

## Ten-Second Travel Estimate

With the current scheduler, a 10-second hold produces:

- one initial 10-second seek;
- 38 first-stage ticks from 250ms through 3,950ms;
- 60 second-stage ticks from 4,050ms through 9,950ms.

The theoretical total is:

```text
10 + (38 * 12) + (60 * 22) = 1,786 seconds = 29 minutes 46 seconds
```

This satisfies the requested approximate 30-minute travel without making the first four seconds excessively aggressive.

## Display Contract

`computeDisplayPositionMs` remains conceptually unchanged:

- the real seek target drives minute and second-tens movement;
- the seconds ones digit is derived from whole physical hold seconds;
- quick release still leaves a normal 10-second short seek;
- negative modulo keeps rewind display digits valid;
- the final display and real target remain clipped to video boundaries.

Only comments and tests should be adjusted where they still describe the former five-second/18-second behavior.

## Test Design

Extend `TvSeekControllerTest` with focused, deterministic checks:

- `holdMs=100` returns 10;
- `holdMs=250` and `3,999` return 12;
- `holdMs=4,000` and later return 22;
- a simulated 100ms scheduler loop for a 10-second hold totals 1,786 seconds and stays within the PRD tolerance;
- the seconds ones digit is stable within one physical second and changes once after crossing the next second;
- rewind display uses positive modulo;
- display and actual targets clip at start/end boundaries.

`TvPlayerRouteControlContractTest` should continue verifying that repeat events do not add a second native repeat stream on top of the internal 100ms scheduler. It must also verify that a direction-key `KeyUp` calls `continuousSeekState.stop()` so no additional tick can be emitted after release.

## Risk and Rollback

The main risk is excessive backend/player-engine seek traffic, but request frequency is unchanged at 100ms; only target distance changes. If device testing shows decoder instability, first reduce or restore the second-stage step while preserving the accepted four-second boundary and new tests. Restore the former threshold only when device evidence shows the four-second boundary itself is unsafe.
