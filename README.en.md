# release-skill-action

[简体中文](README.md) | English

A GitHub Action (composite) that packages a Skill into a zip file following a whitelist and uploads it to a GitHub Release.

## Usage

Create a workflow in the repository containing the Skill to be packaged.

Choose one of the following reference methods:

- `@v1`: the stable major-version tag, updated automatically with each release; recommended for production
- `@main`: tracks the latest code on the main branch

```yaml
name: Release Skill

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: BlazeSnow/release-skill-action@v1
        with:
          skill-name: MySkill
          skill-lower-name: myskill
          base-dir: .
          extra-files: |
            extra.txt
            assets/icons
```

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `skill-name` | Yes | Skill name, used in the zip file name |
| `skill-lower-name` | Yes | Lowercase skill name (the actual deployment name); also the root directory name inside the zip |
| `base-dir` | Yes | The BASE directory where the whitelisted files live (relative to the repository root) |
| `extra-files` | No | Extra files or folders to copy, one per line, relative to the BASE directory; `#` comments are supported |
| `tag` | No | The tag of the target Release; defaults to the current ref name (a tag push trigger is recommended) |
| `token` | No | GitHub Token; defaults to `github.token` |

## Outputs

| Output | Description |
| --- | --- |
| `zip-name` | Name of the generated zip file |
| `zip-path` | Absolute path of the generated zip file |
| `version` | The version used |

## Packaging rules

1. Copy the whitelisted files from the BASE directory to `dist/<skill-lower-name>`:
   - Required: `SKILL.md` (the action fails if missing)
   - Optional: `references/`, `scripts/`, `CHANGELOG.md`, `LICENSE`, `README.md`, `VERSION`
2. Package the result as a zip with `<skill-lower-name>` as the root directory.
3. The zip file is named `<skill-name>-Skill-<version>.zip`.
4. Upload to the GitHub Release: if the Release already exists, the asset is uploaded and any same-name asset is overwritten; otherwise the Release is created with auto-generated notes.

## Version

Priority from highest to lowest:

1. The first line of the `VERSION` file in the BASE directory
2. The `tag` input
3. The current ref name (`github.ref_name`, e.g. `v1.2.3` on a tag push)

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) (in Chinese) for implementation details, local tests, and coding conventions.
