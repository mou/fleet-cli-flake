{
  description = "Rancher Fleet CLI, built from source at a pinned release tag";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
  }: let
    # The Fleet release to build. Override any of these three when you want a
    # different tag (see `fleet.override` note below).
    #
    #   version    the git tag, without the leading "v"
    #   srcHash    hash of the GitHub source tarball for that tag
    #   vendorHash hash of the vendored Go module dependencies
    #
    # To bump the tag:
    #   1. srcHash:
    #        nix-prefetch-url --unpack \
    #          https://github.com/rancher/fleet/archive/refs/tags/v<version>.tar.gz
    #        nix hash convert --hash-algo sha256 --to sri <base32-output>
    #   2. vendorHash: set it to nixpkgs.lib.fakeHash, run `nix build`, and copy
    #      the "got:" hash from the error into place.
    defaults = {
      version = "0.15.4";
      srcHash = "sha256-wyhLs1vZI8wtIu2rJZYT78GXe9t2VQqhM+MlNlNx6pU=";
      vendorHash = "sha256-QIJJaU7UhTbnwhCB2Jx2jQLMi3+VeFispDffksZ1YvQ=";
    };

    # Package builder, independent of the target system. Exposed as an overlay
    # so downstream flakes can consume it with either
    #   overlays = [ inputs.fleet-cli.overlays.default ];   # then pkgs.fleet
    # or
    #   inputs.fleet-cli.packages.${system}.fleet
    mkFleet = {
      lib,
      stdenv,
      buildGoModule,
      fetchFromGitHub,
      installShellFiles,
      version ? defaults.version,
      srcHash ? defaults.srcHash,
      vendorHash ? defaults.vendorHash,
    }:
      buildGoModule {
        pname = "fleet";
        inherit version vendorHash;

        src = fetchFromGitHub {
          owner = "rancher";
          repo = "fleet";
          rev = "v${version}";
          hash = srcHash;
        };

        nativeBuildInputs = [installShellFiles];

        # Only build the `fleet` CLI (cmd/fleetcli), not the controller/agent.
        subPackages = ["cmd/fleetcli"];

        env.CGO_ENABLED = 0;

        # Mirror upstream .goreleaser.yaml ldflags for the CLI.
        ldflags = [
          "-s"
          "-w"
          "-X github.com/rancher/fleet/pkg/version.Version=v${version}"
        ];

        # The binary is named after its package dir (fleetcli); ship it as `fleet`.
        # Then generate shell completions from the CLI itself. Guarded so it is
        # skipped when cross-compiling (can't execute a foreign-arch binary).
        postInstall = ''
          mv "$out/bin/fleetcli" "$out/bin/fleet"
        ''
        + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
          installShellCompletion --cmd fleet \
            --bash <($out/bin/fleet completion bash) \
            --zsh  <($out/bin/fleet completion zsh) \
            --fish <($out/bin/fleet completion fish)
        '';

        doCheck = true;

        meta = with lib; {
          description = "Rancher Fleet CLI (GitOps at scale for Kubernetes clusters)";
          homepage = "https://github.com/rancher/fleet";
          license = licenses.asl20;
          mainProgram = "fleet";
          platforms = platforms.unix;
        };
      };

    overlay = final: _prev: {
      fleet = final.callPackage mkFleet {};
    };
  in
    {
      overlays.default = overlay;
    }
    // utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [overlay];
      };
    in {
      packages = {
        fleet = pkgs.fleet;
        default = pkgs.fleet;
      };

      apps = rec {
        fleet = {
          type = "app";
          program = "${pkgs.fleet}/bin/fleet";
        };
        default = fleet;
      };
    });
}
