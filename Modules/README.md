# Amethyst Modules

Put bundled app modules under `Modules/<module-id>/module.json`. The build copies this directory into `AngelAuraAmethyst.app/Modules`.

```json
{
  "identifier": "example",
  "name": "Example App",
  "subtitle": "Needs host JIT",
  "imageName": "icon.png",
  "entrypoint": "example",
  "requiresJIT": true,
  "requiresMemoryLimit": true,
  "requiresExtendedVirtualAddressing": false,
  "storageSubdirectories": [
    "Software"
  ],
  "debugInfo": {
    "runtime": "native",
    "notes": "Shown in logs and useful for launcher diagnostics"
  }
}
```

Current launch types:

| Field | Behavior |
|---|---|
| `entrypoint` | Native in-process module entry. Add the handler in the app before packaging that module. |
| `launchURL` | Opens a URL after required JIT checks pass. Useful for bridge modules or diagnostics. |

Modules default to `requiresJIT: true`. Keep each module's data in `AM_MODULES_HOME/<module-id>` and packaged resources in `AngelAuraAmethyst.app/Modules/<module-id>`.
`storageSubdirectories` are created under the module data directory when the module is registered.
