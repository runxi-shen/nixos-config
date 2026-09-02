# Apps

Nix [apps](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run#apps) run with
`nix run .#<name>`, built by the `mkApp` helper in `flake.nix`.

Only `aarch64-darwin` exists. The `x86_64-linux` and `aarch64-linux` app sets drove the
`nixosConfigurations` this repo no longer has, and `x86_64-darwin` became unreachable when
nixpkgs 26.11 dropped that platform.

| app | what it does |
|---|---|
| `build` | build this Mac's system closure; does **not** switch |
| `build-switch` | build and activate (needs sudo; Touch ID is enabled) |
| `rollback` | list generations and switch back to one |
| `clean` | garbage-collect generations older than 7 days |
| `check-keys`, `copy-keys`, `create-keys` | age key management for agenix |

`build`, `build-switch` and `rollback` resolve the target host at runtime from
`scutil --get LocalHostName`, since `darwinConfigurations` is keyed by hostname. Pass a host
explicitly to override: `nix run .#build-switch -- <host>`.

There is deliberately no `apply`. It was upstream's fresh-install onboarding script: it
`sed`-replaced `%USER%` tokens across every file in the tree and spliced `flake.nix` against
an anchor that no longer exists, so running it on a configured machine would corrupt it.
