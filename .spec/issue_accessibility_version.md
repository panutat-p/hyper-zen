# Accessibility Version Display Issue

## Problem

Homebrew installs versioned executables such as:

```text
hyper-zen-0.1.3
```

The file is installed correctly, but macOS Accessibility settings displays it
as:

```text
hyper-zen-0.1
```

## Root Cause

macOS treats the final `.3` as a filename extension and hides it in system UI.
This is display behavior only; the installed executable and its Accessibility
authorization path remain `hyper-zen-0.1.3`.

## Decision

Use a versioned executable name without dots:

```text
hyper-zen-v0_1_3
```

This keeps the full version visible in Accessibility settings while retaining
a distinct executable for each ad-hoc-signed release.

## Required Changes

Update the Homebrew formula template and generated formula to install and run:

```ruby
versioned_name = "hyper-zen-v#{version.tr('.', '_')}"
bin.install "hyper-zen" => versioned_name
```

Use the same name in the service command and Accessibility caveat. Update
HyperZen's README and release text to show the underscore-based executable
name.

## Upgrade Guidance

After upgrading, users must enable the new versioned executable in
**System Settings > Privacy & Security > Accessibility**, remove the old entry,
and restart the Homebrew service.
