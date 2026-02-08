# PhoenixBoot Configuration (JSON5)

PhoenixBoot prefers a single config file over ad-hoc exported environment variables.

## Files

`pf.py` loads (in order):

1. `phoenixboot.config.json5` (repo defaults)
2. `phoenixboot.config.local.json5` (your machine overrides; gitignored)

## Global defaults (`globals`)

The `globals` object defines defaults for pf parameters such as `iso_path`,
`usb_device`, `firmware_path`, `name`, etc. Those keys become available inside
tasks (e.g. `$iso_path`) and are also injected as environment variables
(with uppercase aliases like `ISO_PATH`), so legacy shell scripts continue to
see the values without extra exports.

```js5
{
  globals: {
    iso_path: "/home/you/Downloads/ubuntu.iso",
    usb_device: "/dev/sdX",
  },
}
```

Now you can run:

```bash
./pf.py secureboot-create
./pf.py secureboot-create-usb
```

and the central config will supply the necessary parameters.

## Legacy environment overrides (`env`)

The `env` object still works (pf injects those keys into every task, overriding
your shell environment), but prefer `globals` for task-level defaults and
reserve `env` for very specific overrides.

## Optional: point pf.py at another config

```bash
./pf.py config=path/to/config.json5 <task>
```
