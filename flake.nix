{
  description = "Typed Common Lisp interfaces to Git and GHQ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-process-kit = {
      url = "github:nerima-lisp/cl-process-kit/v3.2.0";
      flake = false;
    };
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      flake = false;
    };
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v2.3.0";
      flake = false;
    };
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v2.2.0";
      flake = false;
    };
    cl-date-kit = {
      url = "github:nerima-lisp/cl-date-kit/v1.0.0";
      flake = false;
    };
    cl-concurrent-kit = {
      url = "github:nerima-lisp/cl-concurrent-kit/v0.6.1";
      flake = false;
    };
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
      flake = false;
    };
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.5.0";
      flake = false;
    };

    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-process-kit,
      cl-weave,
      cl-boundary-kit,
      cl-log-kit,
      cl-date-kit,
      cl-concurrent-kit,
      cl-host-kit,
      cl-codec-kit,
      cl-nix-forge,
      paredit-cli,
      treefmt-nix,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      testTimeout = 120;
      cl = cl-nix-forge.lib.${builtins.head systems};
      clProcessKitVersion = cl.fromAsdSystem (cl-process-kit + "/cl-process-kit.asd");
      clWeaveVersion = cl.fromAsdSystem (cl-weave + "/cl-weave.asd");
      clBoundaryKitVersion = cl.fromAsdSystem (cl-boundary-kit + "/cl-boundary-kit.asd");
      clLogKitVersion = cl.fromAsdSystem (cl-log-kit + "/cl-log-kit.asd");
      clDateKitVersion = cl.fromAsdSystem (cl-date-kit + "/cl-date-kit.asd");
      clConcurrentKitVersion = cl.fromAsdSystem (cl-concurrent-kit + "/cl-concurrent-kit.asd");
      clHostKitVersion = cl.fromAsdSystem (cl-host-kit + "/cl-host-kit.asd");
      clCodecKitVersion = cl.fromAsdSystem (cl-codec-kit + "/cl-codec-kit.asd");
    in
    cl.mkPackageFlake {
      inherit self systems nixpkgs;

      pname = "cl-vcs-kit";
      asd = ./cl-vcs-kit.asd;
      root = ./.;
      meta = {
        description = "Typed Common Lisp interfaces to Git and GHQ";
        license = nixpkgs.lib.licenses.mit;
      };

      lispDependencies =
        ctx:
        let
          clHostKit = ctx.cl.lispDerivation {
            lispSystem = "cl-host-kit";
            version = clHostKitVersion;
            src = cl-host-kit;
          };
          clBoundaryKit = ctx.cl.lispDerivation {
            lispSystem = "cl-boundary-kit";
            version = clBoundaryKitVersion;
            src = cl-boundary-kit;
            lispDependencies = [ clHostKit ];
          };
          clDateKit = ctx.cl.lispDerivation {
            lispSystem = "cl-date-kit";
            version = clDateKitVersion;
            src = cl-date-kit;
          };
          clConcurrentKit = ctx.cl.lispDerivation {
            lispSystem = "cl-concurrent-kit";
            version = clConcurrentKitVersion;
            src = cl-concurrent-kit;
            lispDependencies = [
              clBoundaryKit
              clDateKit
            ];
          };
          clLogKit = ctx.cl.lispDerivation {
            lispSystem = "cl-log-kit";
            version = clLogKitVersion;
            src = cl-log-kit;
            lispDependencies = [
              clDateKit
              clConcurrentKit
              clHostKit
            ];
          };
          clCodecKit = ctx.cl.lispDerivation {
            lispSystem = "cl-codec-kit";
            version = clCodecKitVersion;
            src = cl-codec-kit;
          };
          clWeave = ctx.cl.lispDerivation {
            lispSystem = "cl-weave";
            version = clWeaveVersion;
            src = cl-weave;
          };
          clProcessKit = ctx.cl.lispDerivation {
            lispSystem = "cl-process-kit";
            version = clProcessKitVersion;
            src = cl-process-kit;
            lispDependencies = [
              clBoundaryKit
              clLogKit
              clCodecKit
              clConcurrentKit
            ];
            lispCheckDependencies = [ clWeave ];
          };
        in
        [
          clProcessKit
          clHostKit
          clLogKit
        ];

      lispCheckDependencies = ctx: [
        (ctx.cl.lispDerivation {
          lispSystem = "cl-weave";
          version = clWeaveVersion;
          src = cl-weave;
        })
      ];

      packageArgs = ctx: {
        nativeCheckInputs = [
          ctx.pkgs.git
          ctx.pkgs.ghq
        ];
      };

      timeoutSeconds = testTimeout;
      treefmt.evalModule = treefmt-nix.lib.evalModule;
      devShellPackages = ctx: [
        ctx.pkgs.git
        ctx.pkgs.ghq
      ];
      docs = {
        root = ./.;
        fileset = nixpkgs.lib.fileset.unions [
          ./docs/mkdocs.yml
          ./docs/src
        ];
        mkdocsYmlName = "docs/mkdocs.yml";
      };
      extraOutputs = ctx: {
        checks.paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
          inherit (ctx) src;
          name = "cl-vcs-kit-paredit-lint";
        };
      };
      overrideOutputs =
        ctx:
        let
          testRunner = ctx.pkgs.writeShellApplication {
            name = "cl-vcs-kit-test";
            runtimeInputs = [
              ctx.pkgs.git
              ctx.pkgs.ghq
            ];
            text = ''
              exec ${ctx.generated.apps.test.program} "$@"
            '';
          };
        in
        {
          apps.test = {
            type = "app";
            program = ctx.pkgs.lib.getExe testRunner;
            meta = ctx.generated.apps.test.meta;
          };
        };
    };
}
