# CONDITIONS AND ASSERTIONS

Conditions and assertions can be used to throw human readable exceptions and
to create conditional terraform resources or parameters.

`assertions` and `warnings` are internal options and do not appear in the
generated options reference; this section is their documentation.

## assertions

Add an entry to the `assertions` option to state a condition that has to hold
for the configuration to be valid. Every failing assertion is collected, so one
run tells you about every problem at once.

```nix
config = {
  assertions = [
    {
      assertion = cfg.parameter != "fail";
      message = "parameter is set to fail!";
    }
  ];

  resource.aws_what_ever."${cfg.parameter}" = {
    I = "love nixos";
  };
};
```

A failing assertion aborts terranix before any terraform JSON is written.

```
error:
       Failed assertions:
       - parameter is set to fail!
```

## warnings

`warnings` is the non-fatal counterpart. Every string in the list is printed
while the configuration is evaluated, and the terraform JSON is still written.
A failing assertion aborts before warnings are shown, so pending warnings do
not print alongside it.

```nix
config = {
  warnings = optional (config.backend.etcd != null)
    "the etcd backend is deprecated, migrate to s3";
};
```

## mkAssert

`mkAssert` guards a single value rather than the whole configuration, and
throws on the first failure it reaches. Prefer `assertions`, and reach for
`mkAssert` only to protect a value that must not be evaluated at all.

```nix
config = mkAssert (cfg.parameter != "fail") "parameter is set to fail!" {
  resource.aws_what_ever."${cfg.parameter}" = {
    I = "love nixos";
  };
};
```
