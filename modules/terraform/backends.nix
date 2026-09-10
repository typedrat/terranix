# manage backend configurations and terraform_remote_state configurations
{ config, lib, ... }:

with lib;

let

  cfg = config.backend;

  localSubmodule = types.submodule {
    options = {
      path = mkOption {
        type = with types; str;
        description = ''
          path to the state file
        '';
      };
    };
  };

  s3Submodule = types.submodule {
    options = {
      bucket = mkOption {
        type = with types; str;
        description = ''
          bucket name
        '';
      };
      key = mkOption {
        type = with types; str;
        description = ''
          path to the state file in the bucket
        '';
      };
      region = mkOption {
        type = with types; str;
        description = ''
          region of the bucket
        '';
      };
      encrypt = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = ''
          enable server side encryption of the state file
        '';
      };
      use_lockfile = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = ''
          enable locking directly into the configured bucket for the state
        '';
      };
      skip_credentials_validation = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = ''
          skip credentials validation via the STS API
        '';
      };
      skip_region_validation = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = ''
          skip validation of provided region name
        '';
      };
    };
  };

  etcdSubmodule = types.submodule {
    options = {
      path = mkOption {
        type = with types; str;
        description = ''
          The path where to store the state
        '';
      };
      endpoints = mkOption {
        # todo : type should be listOf str
        type = with types; str;
        description = ''
          A space-separated list of the etcd endpoints
        '';
      };
      username = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          the username
        '';
      };
      password = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          the password
        '';
      };
    };
  };

in
{

  options.backend.local = mkOption {
    default = null;
    type = with types; nullOr localSubmodule;
    description = ''
      local backend
      https://www.terraform.io/docs/backends/types/local.html
    '';
  };

  options.remote_state.local = mkOption {
    default = { };
    type = with types; attrsOf localSubmodule;
    description = ''
      local remote state
      https://www.terraform.io/docs/backends/types/local.html
    '';
  };

  options.backend.s3 = mkOption {
    default = null;
    type = with types; nullOr s3Submodule;
    description = ''
      s3 backend
      https://www.terraform.io/docs/backends/types/s3.html
    '';
  };

  options.remote_state.s3 = mkOption {
    default = { };
    type = with types; attrsOf s3Submodule;
    description = ''
      s3 remote state
      https://www.terraform.io/docs/backends/types/s3.html
    '';
  };

  options.backend.etcd = mkOption {
    default = null;
    type = with types; nullOr etcdSubmodule;
    description = ''
      etcd backend
      https://www.terraform.io/docs/backends/types/etcd.html
    '';
  };

  options.remote_state.etcd = mkOption {
    default = { };
    type = with types; attrsOf etcdSubmodule;
    description = ''
      etcd remote state
      https://www.terraform.io/docs/backends/types/etcd.html
    '';
  };

  config =
    let
      backends = [ "local" "s3" "etcd" ];
      notNull = element: !(isNull element);

      definedBackends = filter notNull
        (map (backend: config.backend."${backend}") backends);

      allRemoteStates = flatten
        (map attrNames
          (filter (element: element != { })
            (map (backend: config.remote_state."${backend}") backends)));

      backendConfigurations =
        let
          rule = backend:
            mkIf (config.backend."${backend}" != null) {
              terraform."backend"."${backend}" = config.backend."${backend}";
            };
        in
        mkMerge (map rule backends);

      remoteConfigurations =
        let
          remote = backend:
            mkIf (config.remote_state."${backend}" != { }) {
              data."terraform_remote_state" = mapAttrs
                (name: value: {
                  config = value;
                  backend = "${backend}";
                })
                config.remote_state."${backend}";
            };
        in
        mkMerge (map remote backends);
    in
    mkMerge [
      backendConfigurations
      remoteConfigurations
      {
        assertions = [
          {
            assertion = length definedBackends < 2;
            message = "You defined multiple backends, stick to one!";
          }
          {
            assertion = allRemoteStates == unique allRemoteStates;
            message = "You defined multiple terraform_states with the same name!";
          }
        ];
      }
    ];

}
