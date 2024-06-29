{
  description = "Hackman raspberry pi NixOS example";
  nixConfig = {
    extra-substituters = [ "https://raspberry-pi-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "raspberry-pi-nix.cachix.org-1:WmV2rdSangxW0rZjY/tBvBDSaNFQ3DyEQsVw8EvHn9o="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    raspberry-pi-nix.url = "github:9gel/raspberry-pi-nix/f1bf6b9";
  };

  outputs = { self, nixpkgs, raspberry-pi-nix }:
    let
      configuration-nix = { config, pkgs, ... }: {
        system.stateVersion = "23.11";
        raspberry-pi-nix = {
          uboot.enable = false;
          libcamera-overlay.enable = false;
        };
        time.timeZone = "Asia/Hong_Kong";
        systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
	programs.direnv.enable = true;
        virtualisation.docker = {
          enable = true;
          enableOnBoot = false;  # only start when needed
        };
        environment = {
          systemPackages = with pkgs; [ vim curl bluez bluez-tools networkmanager ];
        };
        services = {
          openssh.enable = true;
          avahi = {
            enable = true;
          };
        };
        users = {
          users.pi = {
            isNormalUser = true;
            extraGroups = ["wheel" "adm" "dialout" "cdrom" "sudo" "audio" "video"
                           "plugdev" "games" "users" "input" "render" "netdev"
                           "gpio" "i2c" "spi" "docker"];
            openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCqt4IWvAz6nSP/ayD2psouqtffu7O8ZMs5RoCsKtsG3KTTm/RWwDAcrWP1QrWVlbz/QWpjB6mt6z8rnTC3Q4r9/o0k4TShlypnWt901LHMPB67oVi4H8EZD7hJOk/G+dfVhwlEw4kRb2j2zJFqlokDF9wPwgT7baOYL5kq+hCXoKgelYS2wMScPP4hs3iHli+fQbcAf/Dd36Q7s4c5CQqZsmTbS+LcprhElRl1W3W8vjel3S3Zuzua94GJNnsZE2P7/DLf1EdjMrNTb+w3RSVKT7XihV8obAMlw5p4/ssUvcAnTWRVpftvXLxdTZDhodW3ewmxmTdBrSbpd/DsJIfdIgGeWlLCB9drCoR8oLPD69iuWfz9HHuuZsC5Ic7/H9hBWT92Fn0E0hE/FFNF6FNaZdd3/Occ5hObIyZPz+DsrQemzP/pn4A7/ahxHfrFd1qfLZSU6yclvgoJZDuiWIkPmVjH50rjbiqoKplm3a4ahGggVltWI19CjYmG5IF1xeU= me@example.lan"
            ];
          };
        };
        security.sudo.extraRules = [{
          users = [ "pi" ];
          commands = [{
            command = "ALL";
            options = [ "NOPASSWD" ];
          }];
        }];
        networking = {
          hostName = "hackman";
          networkmanager.enable = true;
          useDHCP = false;
          interfaces.end0.useDHCP = true;
          wireless.networks = {
            dsl = {
              useDHCP = true;
              psk = "0xdeadbeef";
            };
          };
        };
        hardware = {
          bluetooth.enable = true;
          raspberry-pi = {
            config = {
             all = {
                options = {
                  enable_uart = {
                    enable = true;
                    value = true;
                  };
                  arm_64bit = {
                    enable = true;
                    value = true;
                  };
                  arm_boost = {
                    enable = true;
                    value = true;
                  };
                  disable_fw_kms_setup = {
                    enable = true;
                    value = true;
                  };
                  camera_auto_detect = {
                    enable = false;
                    value = false;
                  };
                  display_auto_detect = {
                    enable = true;
                    value = true;
                  };
                  auto_initramfs = {
                    enable = true;
                    value = true;
                  };
                  max_usb_current = {
                    enable = true;
                    value = true;
                  };
                  usb_max_current_enable = {
                    enable = true;
                    value = true;
                  };
                };
                base-dt-params = {
                  spi = {
                    enable = true;
                    value = "on";
                  };
                  audio = {
                    enable = true;
                    value = "on";
                  };
                  nvme = {
                    enable = true;
                    value = "on";
                  };
                  uart0 = {
                    enable = true;
                    value = "on";
                  };
                  pciex1_gen = {
                    enable = true;
                    value = "3";
                  };
                  uart0_console = {
                    enable = true;
                    value = "on";
                  };
                };
              };
            };
          };
        };
      };

    in

    {
      nixosConfigurations = {
        hackman = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ raspberry-pi-nix.nixosModules.raspberry-pi configuration-nix ];
        };
      };
    };
}
