# Renovate

Using Renovate to automatically search for updates makes it very easy to keep everything in the cluster up-to-date. The easiest way to setup Renovate, is to use the [Renovate bot](https://github.com/renovatebot/renovate).

I'll leave my renovate config here:

```json
// .github/renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base"
  ],
  "dependencyDashboardTitle": "Renovate Dashboard 🤖",
  "commitMessagePrefix": "🤖",
  "reviewers": ["chrede88"],
  "timezone": "Europe/Zurich",
  "schedule": [
    "after 6pm and before 6am every weekday",
    "every weekend"
  ],
  "ignorePaths": ["/docs/*","/network/*"],
  "flux": {
    "fileMatch": [
      "(^|/)cluster/kubernetes/.+\\.ya?ml"
    ]
  },
  "helm-values": {
    "fileMatch": [
      "(^|/)cluster/kubernetes/.+\\.ya?ml$"
    ]
  },
  "kubernetes": {
    "fileMatch": [
      "(^|/)cluster/kubernetes/.+\\.ya?ml$"
    ]
  },
  "packageRules": [
    {
      "matchUpdateTypes": ["major"],
      "labels": ["type/major"]
    },
    {
      "matchUpdateTypes": ["minor"],
      "labels": ["type/minor"]
    },
    {
      "matchUpdateTypes": ["patch"],
      "labels": ["type/patch"]
    }
  ]
}
```

## Other github work flows
I've also setup a couple of workflows for github labels.

### Sync Labels
The first workflow makes sure the labels I want to use are created and the rest are removed.

```yaml
# .github/workflows/sync_labels.yaml
name: Sync labels
on:
  push:
    paths: [".github/labels.yaml"]
  workflow_dispatch:

permissions:
  contents: read
  issues: write

jobs:
  labels:
    runs-on: ubuntu-latest

    steps:
      - name: checkout
        uses: actions/checkout@v4

      - name: 
        uses: EndBug/label-sync@v2
        with:
          config-file: .github/labels.yaml
          delete-other-labels: true
          token: ${{ secrets.GITHUB_TOKEN }}
```
The labels are defined in `.github/labels.yaml`.

```yaml
# .github/labels.yaml
# Semantic Type
- name: type/digest
  color: "FFEC19"
- name: type/patch
  color: "FFEC19"
- name: type/minor
  color: "FF9800"
- name: type/major
  color: "F6412D"
# Area
- name: area/kubernetes
  color: "72ccf3"
  description: "Changes made to kubernetes resources"
- name: area/github
  color: "72ccf3"
  description: "Changes made in the github directory"
# Others
- name: bug
  color: "d73a4a"
  description: "Something isn't working"
- name: keep
  color: "01717f"
  description: "Keep issue open"
```

### Adding labels to pull requests
The second workflow automatically adds labels to pull requests.

```yaml
# .github/workflows/label_marker.yaml
name: "Labeler"

on:
  workflow_dispatch:
  pull_request:
    branches: ["main"]

permissions:
  contents: read
  pull-requests: write

jobs:
  labeler:
    name: Labeler
    runs-on: ubuntu-latest
    steps:
      - name: Labeler
        uses: actions/labeler@v5
        with:
          configuration-path: .github/labeler.yaml
```

The workflow uses the config set in `.github/labeler.yaml`.

```yaml
# .github/labeler.yaml
area/kubernetes:
- changed-files:
  - any-glob-to-any-file: "cluster/kubernetes/**/*"

area/github:
- changed-files:
  - any-glob-to-any-file: ".github/**/*"
```