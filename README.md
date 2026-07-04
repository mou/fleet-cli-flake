# fleet-cli

A self-contained Nix flake that builds the [Rancher Fleet](https://github.com/rancher/fleet)
CLI (`fleet`) from source at a pinned release tag. Shell completions for bash,
zsh, and fish are generated at build time and shipped inside the package.

Currently pinned to **v0.15.4**.

## Outputs

| Output | What it is |
| --- | --- |
| `packages.<system>.fleet` / `.default` | the `fleet` CLI derivation |
| `overlays.default` | adds `pkgs.fleet` |
| `apps.<system>.fleet` / `.default` | `nix run` entry point |

## Use it

### Run without installing

```console
nix run github:mou/fleet-cli-flake -- --help
```

### As a flake input

```nix
{
  inputs.fleet-cli.url = "github:mou/fleet-cli-flake";
  # share your own nixpkgs pin (optional but recommended):
  inputs.fleet-cli.inputs.nixpkgs.follows = "nixpkgs";
}
```

Then either reference the package directly:

```nix
environment.systemPackages = [ inputs.fleet-cli.packages.${system}.fleet ];
# or, home-manager:
home.packages = [ inputs.fleet-cli.packages.${system}.fleet ];
```

or add the overlay and use `pkgs.fleet`:

```nix
nixpkgs.overlays = [ inputs.fleet-cli.overlays.default ];
# ... then `pkgs.fleet` is available everywhere
```

### Ad-hoc install

```console
nix profile install github:mou/fleet-cli-flake#fleet
```

## Shell completions

Completions are installed into the standard locations inside the package:

- `share/bash-completion/completions/fleet.bash`
- `share/zsh/site-functions/_fleet`
- `share/fish/vendor_completions.d/fleet.fish`

They load **automatically** when `fleet` is installed into a profile that your
shell scans at startup — i.e. via NixOS `environment.systemPackages`,
home-manager `home.packages`, or `nix profile install` — provided your shell's
completion system is enabled (`programs.zsh.enable`, `programs.bash.completion.enable`,
`programs.fish.enable`, etc.). No extra wiring is needed.

> **Note — dev shells:** completions do *not* auto-load when `fleet` is merely
> pulled into a `nix develop` / direnv dev shell. A dev shell only adds the
> binary to `PATH`; it neither extends `$NIX_PROFILES` nor re-runs `compinit`
> after the shell has started. For live completions, install the package into a
> profile as above, or run `source <(fleet completion zsh)` in the shell.

## Bumping the release tag

Override the three inputs in `flake.nix` (they are documented inline):

1. **`version`** — the git tag without the leading `v`.
2. **`srcHash`**:
   ```console
   nix-prefetch-url --unpack \
     https://github.com/rancher/fleet/archive/refs/tags/v<version>.tar.gz
   nix hash convert --hash-algo sha256 --to sri <base32-output>
   ```
3. **`vendorHash`** — set it to `nixpkgs.lib.fakeHash`, run `nix build`, and copy
   the `got:` hash from the error into place.

You can also override at the call site without editing the flake:

```nix
pkgs.fleet.override {
  version    = "0.16.0";
  srcHash    = "sha256-...";
  vendorHash = "sha256-...";
}
```
