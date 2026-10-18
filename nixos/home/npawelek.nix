{ config, lib, osConfig, pkgs, ... }:
{
  # Release of first install. Never bump after install.
  home.stateVersion = "26.05";

  # Per-host SSH key (GitHub etc.), created once on first activation and never in the Nix store
  home.activation.sshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.ssh/id_ed25519" ]; then
      run mkdir -p "$HOME/.ssh"
      run chmod 700 "$HOME/.ssh"
      run ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" \
        -C "${config.home.username}@${osConfig.networking.hostName}" \
        -f "$HOME/.ssh/id_ed25519"
    fi
  '';

  # nixd: Nix language server for Nix IDE; nixfmt formats on save.
  home.packages = with pkgs; [ nixd nixfmt ];

  # mise global settings (~/.config/mise/config.toml); the repo's .mise.toml pins tools.
  xdg.configFile."mise/config.toml".source = (pkgs.formats.toml { }).generate "mise-config" {
    settings = {
      # mise compiles everything from source on NixOS by default; nix-ld (base.nix) runs
      # the prebuilt binaries instead.
      all_compile = false;
      # nak is a cgo `go install`, and there is no C compiler here. Not needed on pella.
      disable_tools = [ "go:github.com/fiatjaf/nak" ];
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Nathan Pawelek";
      email = "4248420+npawelek@users.noreply.github.com";
    };
  };

  # settings.json is a read-only store link: change settings here, not in the UI.
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      # Nix owns versions (flake.lock); VS Code must not update them behind its back.
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      extensions =
        with pkgs.vscode-extensions;
        [
          anthropic.claude-code
          jnoortheen.nix-ide
          ms-python.debugpy
          ms-python.python
          ms-python.vscode-pylance
          ms-python.vscode-python-envs
          redhat.vscode-yaml
        ]
        # Not in nixpkgs. Per-platform build: bundles tofu-ls (static Go binary).
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            publisher = "OpenTofu";
            name = "vscode-opentofu";
            version = "0.6.3";
            arch = "linux-x64";
            hash = "sha256-7Qy9W4hpt63MXx2PzsXOVzueRvTlfsxmw9U1djo6hf0=";
          }
        ];

      userSettings = {
        "workbench.colorTheme" = "Monokai";
        "workbench.sideBar.location" = "right";
        "workbench.secondarySideBar.defaultVisibility" = "hidden";
        "workbench.startupEditor" = "none";
        "editor.tabSize" = 2;
        "editor.wordWrap" = "on";
        "chat.tips.enabled" = false;
        "claudeCode.preferredLocation" = "panel";
        "claudeCode.hideOnboarding" = true;

        "[dockercompose]" = {
          "editor.insertSpaces" = true;
          "editor.tabSize" = 2;
          "editor.autoIndent" = "advanced";
          "editor.defaultFormatter" = "redhat.vscode-yaml";
        };
        "[github-actions-workflow]"."editor.defaultFormatter" = "redhat.vscode-yaml";
        "yaml.schemas".kubernetes = "./kubernetes/**/*.yaml";

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.serverSettings".nixd = {
          formatting.command = [ "nixfmt" ];
          # NixOS option completion/hover from this flake.
          options.nixos.expr = ''(builtins.getFlake "/home/npawelek/github/home-ops/nixos").nixosConfigurations.pella.options'';
        };
        "[nix]"."editor.formatOnSave" = true;
      };
    };
  };

  # Plasma UI fonts (System Settings > Text & Fonts), at Plasma's default sizes. Only
  # these keys are managed; other Plasma settings stay editable in the UI.
  programs.plasma = {
    enable = true;
    fonts =
      let
        sf = pointSize: { family = "SF Pro Text"; inherit pointSize; };
      in
      {
        general = sf 10;
        small = sf 8;
        toolbar = sf 10;
        menu = sf 10;
        windowTitle = { family = "SF Pro Display"; pointSize = 10; };
        fixedWidth = { family = "SF Mono"; pointSize = 10; };
      };
  };
}
