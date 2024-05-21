# Renovate

Using Renovate to automatically search for updates makes it very easy to keep everything in the cluster up-to-date. The easiest way to setup Renovate, is to use the [Renovate bot](https://github.com/renovatebot/renovate).

I'll leave my renovate config here:

```json
// .github/renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base",
    "github>chrede88/home-ops//.github/renovate/grafanadashboards.json",
    "github>chrede88/home-ops//.github/renovate/groups.json",
    "github>chrede88/home-ops//.github/renovate/privatepackages.json"
  ],
  "dependencyDashboardTitle": "Renovate Dashboard 🤖",
  "commitMessagePrefix": "🤖",
  "commitMessageTopic": "{{depName}}",
  "commitMessageExtra": "to {{newVersion}}",
  "commitMessageSuffix": "",
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
  "pre-commit": {
    "enabled": true
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
    },
    {
      "matchDatasources": ["helm"],
      "commitMessageTopic": "chart {{depName}}"
    },
    {
      "matchDatasources": ["docker"],
      "commitMessageTopic": "image {{depName}}"
    }
  ]
}
```

```json
// .github/renovate/grafanadashboards.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "customDatasources": {
    "grafana-dashboards": {
      "defaultRegistryUrlTemplate": "https://grafana.com/api/dashboards/{{packageName}}",
      "format": "json",
      "transformTemplates": [
        "{\"releases\":[{\"version\": $string(revision)}]}"
      ]
    }
  },
  "customManagers": [
    {
      "customType": "regex",
      "description": ["Process Grafana dashboards"],
      "fileMatch": [
        "(^|/)cluster/kubernetes/.+\\.ya?ml$"
      ],
      "matchStrings": [
        "depName=\"(?<depName>.*)\"\\n(?<indentation>\\s+)gnetId: (?<packageName>\\d+)\\n.+revision: (?<currentValue>\\d+)"
      ],
      "autoReplaceStringTemplate": "depName=\"{{{depName}}}\"\n{{{indentation}}}gnetId: {{{packageName}}}\n{{{indentation}}}revision: {{{newValue}}}",
      "datasourceTemplate": "custom.grafana-dashboards",
      "versioningTemplate": "regex:^(?<major>\\d+)$"
    }
  ],
  "packageRules": [
    {
      "matchDatasources": ["custom.grafana-dashboards"],
      "matchUpdateTypes": ["major"],
      "semanticCommitType": "chore",
      "semanticCommitScope": "grafana-dashboards",
      "commitMessageTopic": "dashboard {{depName}}",
      "commitMessageExtra": "({{currentVersion}} → {{newVersion}})"
    }
  ]
}
```

```json
// .github/renovate/groups.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "packageRules": [
    {
      "description": ["Rook-Ceph Group"],
      "groupName": "Rook-Ceph",
      "matchPackagePatterns": ["rook-ceph"],
      "matchDatasources": ["helm"],
      "group": {
        "commitMessageTopic": "{{{groupName}}} group"
      },
      "separateMinorPatch": true
    },
    {
      "description": ["Flux Group"],
      "groupName": "Flux",
      "matchPackagePatterns": ["fluxcd"],
      "matchDatasources": ["docker", "github-tags"],
      "versioning": "semver",
      "group": {
        "commitMessageTopic": "{{{groupName}}} group"
      },
      "separateMinorPatch": true
    }
  ]
}
```

```json
// .github/renovate/privatepackages.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "hostRules": [
    {
      "matchHost": "ghcr.io",
      "hostType": "docker",
      "username": "chree88",
      "encrypted": {
        "password": "..."
      }
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

      - name: sync-labels
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

### Flux diff
I'm also using a workflow to generate a flux diff on each PR.

````yaml
# .github/workflows/flux-diff.yaml
name: "Flux Diff"

on:
  pull_request:
    branches: ["main"]
    paths: ["cluster/kubernetes/**"]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.number || github.ref }}
  cancel-in-progress: true

jobs:
  flux-diff:
    name: Flux Diff
    runs-on: ubuntu-latest
    strategy:
      matrix:
        resource:
          - helmrelease
          - kustomization
    steps:
      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main
        with:
          version: 2.2.3
      - uses: allenporter/flux-local/action/diff@4.3.1
        id: diff
        with:
          live-branch: main
          path: cluster/kubernetes/flux-system
          resource: ${{ matrix.resource }}
      - name: PR Comments
        uses: mshick/add-pr-comment@v2
        if: ${{ steps.diff.outputs.diff != '' }}
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          message-id: ${{ github.event.pull_request.number }}/${{ matrix.resource }}
          message-failure: Unable to post kustomization diff
          message: |
            ```diff
            ${{ steps.diff.outputs.diff }}
            ```
````