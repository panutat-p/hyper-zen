# Menu Bar Animation CPU Usage

## Summary

The animated menu bar icon appears to add steady CPU usage to the `hyper-zen status-icon` helper.

The app is still lightweight in memory, but the continuous SF Symbol animation is probably not ideal for an always-running background menu bar process.

## Current Implementation

The menu bar icon uses Apple native SF Symbols:

- Symbol: `gearshape.fill`
- macOS 15 and newer: continuous `.rotate` symbol effect
- macOS 14 fallback: repeating `.pulse` symbol effect

Relevant file:

- `Sources/hyper-zen/StatusIcon.swift`

## Process Inspected

Running process:

```text
/Users/Panutat/app/hyper-zen/.build/release/hyper-zen status-icon
```

PID at inspection time:

```text
48322
```

## Sample Results

Initial snapshot:

```text
CPU:    3.7%
Memory: 17.8 MB RSS
%MEM:   0.1%
```

20-second sample range:

```text
CPU:    2.2% to 4.6%
Memory: 16.0 MB to 18.8 MB RSS
%MEM:   0.1%
```

## Assessment

Memory usage is acceptable.

CPU usage is higher than expected for a tiny menu bar helper. Since the app otherwise only posts synthetic input every 5 minutes, the steady CPU cost is likely caused by the continuous menu bar icon animation.

This is not dangerous, but it is wasteful for an app intended to run all day.

## Recommendation

Avoid continuous animation for the menu bar icon.

Better options:

- Use a static SF Symbol most of the time.
- Play a short bounce or pulse only when the app starts.
- Play a short animation every 5 minutes when synthetic input is posted.
- Keep the animated symbol code path available, but avoid `.repeat(.continuous)` for normal operation.

Best default:

```text
Static icon normally, short pulse when activity is posted.
```

## Static Icon Follow-up Measurement

The icon was changed from animated `gearshape.fill` to static `gearshape.fill`, then the release build was rebuilt and the LaunchAgent was restarted.

New running process:

```text
/Users/Panutat/app/hyper-zen/.build/release/hyper-zen status-icon
```

PID at follow-up inspection time:

```text
69107
```

20-second static-icon sample range:

```text
CPU:    0.0%
Memory: 24.0 MB to 25.0 MB RSS
%MEM:   0.1% to 0.2%
```

## Follow-up Conclusion

The static icon removed the steady CPU usage seen with the continuous native symbol animation.

Comparison:

```text
Animated icon CPU: 2.2% to 4.6%
Static icon CPU:   0.0%
```

The static icon is the better default for an always-running menu bar helper.
