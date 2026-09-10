{ ... }:
{
  perSystem =
    { pkgs
    , ...
    }:
    {
      checks =
        let
          mockTerraformConfiguration = pkgs.writeText "config.tf.json" "{}";

          mkMockTfPackage = name: pkgs.writeShellApplication
            {
              inherit name;
              text = ''echo "mock ${name} $*"'';
            } // { meta.mainProgram = name; };

          mockTerraform = mkMockTfPackage "mock-terraform";

          legacyWrapper = import ../core/terraform-invocs.nix;

          assertScriptContains = checkName: script: expected:
            pkgs.runCommand checkName { } ''
              scriptText=$(cat ${script}/bin/*)
              for pattern in ${builtins.concatStringsSep " " (map (s: "'${s}'") expected)}; do
                if ! echo "$scriptText" | grep -qF "$pattern"; then
                  echo "FAIL: expected '$pattern' in script"
                  echo "Script contents:"
                  echo "$scriptText"
                  exit 1
                fi
              done
              echo "PASS: ${checkName}" > $out
            '';
        in
        {
          legacy-wrapper-raw-package =
            let
              result = legacyWrapper {
                inherit pkgs;
                terraformConfiguration = mockTerraformConfiguration;
                terraformWrapper = mockTerraform;
              };
            in
            assertScriptContains "legacy-wrapper-raw-package" result.scripts.apply [
              "mock-terraform init"
              "mock-terraform apply"
            ];

          legacy-wrapper-attrset =
            let
              result = legacyWrapper {
                inherit pkgs;
                terraformConfiguration = mockTerraformConfiguration;
                terraformWrapper = {
                  package = mockTerraform;
                  prefixText = "echo test-prefix";
                  suffixText = "echo test-suffix";
                };
              };
            in
            assertScriptContains "legacy-wrapper-attrset" result.scripts.apply [
              "mock-terraform init"
              "mock-terraform apply"
              "echo test-prefix"
              "echo test-suffix"
            ];

          legacy-wrapper-default =
            let
              mockDefault = mkMockTfPackage "terraform";
              result = legacyWrapper {
                inherit pkgs;
                terraformConfiguration = mockTerraformConfiguration;
                terraformWrapper = mockDefault;
              };
            in
            assertScriptContains "legacy-wrapper-default" result.scripts.apply [
              "terraform init"
              "terraform apply"
            ];

          # a failed assertion must not block reading assertions/warnings/_meta,
          # only config; mirrors nixos, where unrelated config stays readable
          failed-assertion-keeps-result-readable =
            let
              result = import ../core/default.nix {
                inherit pkgs;
                modules = [{
                  assertions = [{
                    assertion = false;
                    message = "deliberately failing assertion";
                  }];
                  warnings = [ "deliberately reachable warning" ];
                  _meta.marker = "deliberately reachable meta";
                }];
              };
              ok =
                builtins.elem
                  { assertion = false; message = "deliberately failing assertion"; }
                  result.assertions
                && builtins.elem "deliberately reachable warning" result.warnings
                && result._meta.marker == "deliberately reachable meta";
            in
            assert ok;
            pkgs.runCommand "failed-assertion-keeps-result-readable" { } ''
              echo "PASS" > $out
            '';
        };
    };
}
