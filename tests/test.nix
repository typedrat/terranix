{ nixpkgs, pkgs, lib, terranix, ... }:
with lib;
let
  # example:
  #[ {
  #  text = "assert : don't trigger error on true mkAssert ";
  #  file = ./terranix-tests/05.nix;
  #  success = true;
  #  outputFile = ./terranix-tests/05.nix.output;
  #} ]
  # dedentOutput strips nix's indentation from multi-line error text; only
  # pair it with a failure whose outputFile is written unindented, never
  # with an exact-match success case like the one above.
  terranix-tests = import ./terranix-tests.nix;
  terranix-test-template = { text, file, options ? [ ], success ? true, outputFile ? "", partialMatchOutput ? false, dedentOutput ? false, refuteOutput ? "", ... }:
    ''
      @test "${text}" {
      run ${terranix}/bin/terranix ${concatStringsSep " " options} --pkgs ${nixpkgs} --quiet ${file}

      # edit output to make sure no nix store paths are included
      # - they cause tests to fail depending on environment
      output=$(echo "$output" | sed 's|/nix/store/.*-|<nix store path>-|')
      ${optionalString dedentOutput ''
        # nix indents every continuation line of a multi-line error;
        # strip whatever leading whitespace it used so the width isn't hardcoded
        output=$(echo "$output" | sed 's|^ *||')
      ''}
      ${if success then "assert_success" else "assert_failure"}
      ${optionalString (outputFile != "") "assert_output ${optionalString partialMatchOutput "--partial"} ${escapeShellArg (fileContents outputFile)}"}
      ${optionalString (refuteOutput != "") "refute_output --partial ${escapeShellArg refuteOutput}"}
      }
    '';


  terranix-doc-json-tests = import ./terranix-doc-json-tests.nix;
  terranix-doc-json-test-template = { text, path ? "", file, options ? [ ], success ? true, outputFile ? "", ... }:
    ''
      @test "${text}" {
      run bash -c '${terranix}/bin/terranix-doc-json --quiet ${optionalString (path != "") "--path ${path}"} ${concatStringsSep " " options} --pkgs ${nixpkgs} --quiet ${file} 2>/dev/null'
      ${if success then "assert_success" else "assert_failure"}
      ${optionalString (outputFile != "") "assert_output ${escapeShellArg (fileContents outputFile)}"}
      }
    '';


in
(map terranix-test-template terranix-tests) ++
(map terranix-doc-json-test-template terranix-doc-json-tests)
