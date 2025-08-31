self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  cli-default = self.inputs.caelestia-cli.packages.${system}.default;
  shell-default = self.packages.${system}.with-cli;

  cfg = config.programs.caelestia;
in {
  options = with lib; {
  programs.caelestia = {
      enable = mkEnableOption "Enable Caelestia shell";
      package = mkOption {
        type = types.package;
        default = shell-default;
        description = "The package of Caelestia shell";
      };
      systemd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the systemd service for Caelestia shell";
        };
      };
      settings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Caelestia shell settings";
      };
      extraConfig = mkOption {
        type = types.str;
        default = "";
        description = "Caelestia shell extra configs written to shell.json";
      };
      cli = {
        enable = mkEnableOption "Enable Caelestia CLI";
        package = mkOption {
          type = types.package;
          default = cli-default;
          description = "The package of Caelestia CLI"; # Doesn't override the shell's CLI, only change from home.packages
        };
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = "Caelestia CLI settings";
        };
        extraConfig = mkOption {
          type = types.str;
          default = "{}";
          description = "Caelestia CLI extra configs written to cli.json";
        };
      };
    };
  };

  config = let
    cli = cfg.cli.package or cli-default;
    shell = cfg.package or shell-default;
  in
    lib.mkIf cfg.enable {
      systemd.user.services.caelestia = lib.mkIf cfg.systemd.enable {
        Unit = {
          Description = "Caelestia Shell Service";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
          X-Restart-Triggers = lib.mkIf (cfg.settings != {}) [
            "${config.xdg.configFile."caelestia/shell.json".source}"
          ];
        };

        Service = {
          Type = "exec";
          ExecStart = "${shell}/bin/caelestia-shell";
          Restart = "on-failure";
          RestartSec = "5s";
          TimeoutStopSec = "5s";
          Environment = [
            "QT_QPA_PLATFORM=wayland"
          ];

          Slice = "session.slice";
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };

      xdg.configFile = let
        mkConfig = c:
          lib.pipe (
            if c.extraConfig != ""
            then c.extraConfig
            else "{}"
          ) [
            builtins.fromJSON
            (lib.recursiveUpdate c.settings)
            builtins.toJSON
          ];
      in {
        "caelestia/shell.json".text = mkConfig cfg;
        "caelestia/cli.json".text = mkConfig cfg.cli;
      };

      home.packages = [shell] ++ lib.optional cfg.cli.enable cli;
    };
}
