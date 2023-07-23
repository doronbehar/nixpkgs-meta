{ config, lib, pkgs, ... }:

let
  syncthing-private = {
    folders = {
      "/home/doron/pictures/screenshots" = {
        label = "Screenshots";
        id = "screenshots";
        devices = [ "Office" "Android" ];
      };
      "/home/doron/pictures/DCIM" = {
        id = "camera";
        label = "Android Latest Pictures";
        devices = [ "Office" "Android" ];
      };
      "/home/doron/pictures/kept" = {
        label = "Kept Pictures";
        devices = [ "Android" ];
        ignoreDelete = true;
        versioning = {
          type = "trashcan";
          params.cleanoutDays = "0";
        };
        id = "keptpictures";
      };
      "/home/doron/desktop/university/hw" = {
        label = "Android University Scans";
        id = "scans";
        devices = [ "Office" "Android" ];
      };
      "/home/doron/recordings" = {
        id = "recordings";
        label = "Android Sound Recordings";
        devices = [ "Android" ];
      };
      "/home/doron/documents" = {
        label = "Documents";
        id = "documents";
        devices = [ "Office" "Android" ];
      };
      "/home/doron/desktop/university/yuval-lab-shared-folder/" = {
        label = "Office / Work shared folder";
        id = "office";
        devices = [ "Office" ];
      };
    };
    devices = {
      "Android" = {
        id = "NXHLN7E-6DXUNUG-UPV5BNC-D66WGYG-2GIKDB5-3BUMQU2-NHUIHRC-C2EDTAF";
      };
      "ZENIX" = {
        id = "7PFJLDI-FRSRTON-F3WNQKG-W6ZEM4U-DKIYGO5-U3X2LR5-D2ABWRN-Q4H27A4";
      };
      "Office" = {
        id = "ZM6HBHP-6MLD7G6-KUA3247-ICG3AAL-WJTUPPC-YBNETLL-ASMM3U4-M6SYIQE";
      };
    };
  };
in {
  config = {
    # Syncthing
    services.syncthing = {
      enable = true;
      # Allow folders and devices to be set imperatively
      overrideFolders = true;
      overrideDevices = true;
      settings = {
        inherit (syncthing-private)
          devices
          folders
        ;
      };
      openDefaultPorts = true;
    };
    # Since we don't use custom certificates, we can set this command to
    # whatever we want. Most of the directories are located in /home/doron, and
    # systemd by default removes x and r permission for the users directory.
    systemd.tmpfiles.rules = [
      "d /home/doron 0711 - -"
    ];
    # Put myself in this group
    users.users.doron.extraGroups = [ "syncthing" ];
    # tmpfiles are defined in ~/.config/user-tmpfiles.d/syncthing.conf
  };
}
