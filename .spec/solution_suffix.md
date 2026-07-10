# Versioned Executable Names for Homebrew Accessibility Grants

## Decision

Publish a stable Homebrew formula named `hyper-zen`, while giving the installed
executable a version suffix:

```text
Formula:       hyper-zen
Executable:    hyper-zen-<version>
Accessibility: hyper-zen-<version>
```

For example, version `0.1.0` installs and runs `hyper-zen-0.1.0`. This makes
the entry shown in macOS Accessibility settings clearly identify the release
that the user approved.

The suffix is deliberate: the executable is ad-hoc signed, so an Accessibility
grant for an older build does not authorize a rebuilt or upgraded binary. A
separate, visibly versioned entry communicates that the user must grant access
again after each upgrade.

## Formula Shape

Keep the formula token and install command stable:

```sh
brew install panutat-p/tap/hyper-zen
brew upgrade hyper-zen
```

Rename the binary while installing it, and have the service execute that
versioned binary:

```ruby
class HyperZen < Formula
  # version, URL, checksum, and other metadata omitted

  def install
    bin.install "hyper-zen" => "hyper-zen-#{version}"
  end

  service do
    run [opt_bin/"hyper-zen-#{version}", "status-icon"]
  end
end
```

Homebrew updates the formula metadata for each release, so a restarted service
will run the binary for the newly installed version.

## User Guidance

The formula must include this caveat, with its current `version` interpolated:

```ruby
caveats <<~EOS
  Hyper Zen requires Accessibility permission for Teams presence.

  After each upgrade, enable the newly installed executable in:
  System Settings > Privacy & Security > Accessibility

  Add:
    #{bin}/hyper-zen-#{version}

  Remove the previous Hyper Zen entry, then restart the service:
    brew services restart hyper-zen
EOS
```

## Release Workflow

For every release:

1. Build and publish the archive containing `hyper-zen`.
2. Update the formula `url`, `sha256`, and version.
3. Users run `brew upgrade hyper-zen`.
4. Users grant Accessibility to `hyper-zen-<new-version>` in System Settings.
5. Users run `brew services restart hyper-zen`.

Do not use the version suffix as a substitute for stable signing. It only
makes the required reauthorization explicit. Signing future releases with a
stable Developer ID certificate remains the permanent way to preserve macOS
Accessibility authorization across updates.
