# Renovate

Using Renovate to automatically search for updates to the resources you've deployed in your cluster, and automatically open PRs with when new versions are published, makes it very easy to keep everything in the cluster up-to-date. Combining it with a CD tool like Fluxcd or Argocd, makes a great CI/CD pipeline that all self hosters should consider setting up.

I'll focus exclusively on Github, as that's what I've experience with. Renovate can also be used for Gitlab and BitBucket. You'll have to look elsewhere for documentation on these implimentations.

## Official Renovate Bot

The easiest way to get started with Renovate, is to use the offical [Renovate bot](https://github.com/apps/renovate). The install and inital configuration is quite easy to follow. After the inital setup, the Renovate bot will open an onboarding issue to further guide the final part of the setup.

Setting up the configuration can be a bit more envolved, depending on how many `customManagers`, `packageRules`, `hostRules` etc. you'll need. The official Renovate documentation can be hard to parse and I find the docs a bit confusing to navigate. I'll try to layout my [config](#my-renovate-config) at the end of this document.

## Self Hosting Renovate

Another option is to self host Renovate. You can either run Renovate in your Kubernetes cluster or run it through Github Actions. I'll focus on the Github Actions path. For running Renovate in your own cluster, a good starting point is the github repo for the [Renovate Community Edition](https://github.com/mend/renovate-ce-ee) image.

### Github Action
Running Renovate through Github Actions are essentially the same as using the official Renovate bot. You'll have to create your own Github bot, that'll play the same role as the Renovate bot. Using your own bot gives you more control over the whole process, like how often and when Renovate should check for updated resources. And as long as you don't get hit by rate limits, you can run this more or less 24/7. The configuration is identical and the only downside I know of is that you can't easily pass secrets to the Renovate configuration in a Github Action. This means that using Renovate for any private packages you might have on Github's container repository is hard to accomblish right now. There are ways around this limitation, but they might not cover all needs. I need to access my private packages, which is possible with a hack that'll layout [below](#private-github-packages).

Let's get to acutally setting up Renovate!

1) Create a new Github bot

The first step is to create a new Github bot. You can find this under `Settings -> Developer Settings -> Github Apps`. Give your bot a name. This is the name that will show up for commits and PRs that your bot will create, so pick a nice name. You can change this later without breaking anything (I think). You'll also need to provide a URL to the bot's website, this can just point to your own github profile. Leave the `webhook` and `callback url` stuff blank, you won't need any of this. You'll also have to set the permissions for your bot, these are important as the bot otherwise won't work correctly. Set the following `repository` permissions:

| **Type**      | **Access**      |
| ------------- | ------------- |
| Administration | Read-only |
| Checks | Read & Write |
| Commit statuses | Read & Write |
| Contents | Read & Write |
| Dependabot alerts | Read-only |
| Issues | Read & Write |
| Metadata | Read-only |
| Pull requests  | Read & Write |
| Workflows | Read & Write |

At the time of writing (Oct. 2024) there is a `packages` permission, but it doesn't seem to be completely implimented yet. This might be enough for accessing your own private packages in the future.

And set the following `organization` permissions:

| **Type**      | **Access**      |
| ------------- | ------------- |
| Members | Read-only |

Leave the rest of the settings as default and click on `Create Github App`.

2) Finish Setup of Bot

The next thing to do is to upload a `logo` (profile picture) for your bot. A nice AI generated image of a robot might be nice. A nice logo will give your bot some personality! You should also install the bot to your account. Do this under the `Install` section of the bots settings. Here you can also choose which repositories the bot should have access to. Either leave it at all repositories, or (a better option) choose your cluster repository.
Lastly, you should generate a private key for the bot and download the `.pem` file and note down the bots `App id`. We'll need both for the next part.

3) Setup Github Action

First thing you'll need to do is to create two new repository secrets in your cluster repository. Head over to `Settings -> Secrets and variables -> Actions`, and create a secret called `BOT_APP_ID`. Place your bots ID in this secret. Call the other secret `BOT_PRIVATE_KEY` and place the content of the `.pem` file you just downloaded in this secret.

You're now ready to create the Github Action manifest. Create a new file on the path `.github/workflows/renovate.yaml`. Dump the following `yaml` in this new file:

```yaml
---
name: "Renovate"

on: # <- when this action should run
  workflow_dispatch: # <- this allows you to run it manually

  schedule: # <- we will run it on a schedule
    - cron: "0 * * * *" # Every hour
  push: # <- run if we update the configuration
    branches: ["main"]
    paths:
      - .github/renovate.json
      - .github/renovate/**.json

permissions: # <- set permissions for the default github token
  packages: read

concurrency: # <- ensure workflow triggers are handled concurrently
  group: ${{ github.workflow }}-${{ github.event.number || github.ref }}
  cancel-in-progress: true

env: # <- define some env variables
  LOG_LEVEL: "debug" # <- info or debug
  RENOVATE_AUTODISCOVER: true # <- let renovate discover your repositoties
  RENOVATE_AUTODISCOVER_FILTER: "${{ github.repository }}" # <- limit to this repo only
  RENOVATE_PLATFORM: github # <- pretty obvious
  RENOVATE_PLATFORM_COMMIT: true # <- This will allow the bot to sign the commits (using the private key we just created)
  RENOVATE_BOT_NAME: 'bb-17' # <- my bot name, change this for your bot
  RENOVATE_HOST_RULES: | # private registries/repos <- needed to pass the github token to renovate
    [{"hostType": "docker", "matchHost": "ghcr.io", "username": "${{ github.actor }}", "password": "${{ secrets.GITHUB_TOKEN }}"}]

jobs:
  renovate:
    name: Renovate
    runs-on: ubuntu-latest
    steps:
      - name: Generate Token # <- Generate an access token for the bot
        uses: actions/create-github-app-token@v1
        id: app-token
        with:
          app-id: "${{ secrets.BOT_APP_ID }}" # <- Change this if you called the secret something else
          private-key: "${{ secrets.BOT_PRIVATE_KEY }}" # <- Change this if you called the secret something else

      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: "${{ steps.app-token.outputs.token }}" # <- we are using the generated token

      - name: Renovate # <- Run Renovate
        uses: renovatebot/github-action@v40.3.2
        with:
          configurationFile: .github/renovate.json
          token: "${{ steps.app-token.outputs.token }}"
```

I think the action should run automatically when created, if not you can run it manually. Find the action under the `Action` tab in your repository. If Renovate doesn't find a configuration file in your repository, it should open a new onboarding PR. This PR should contain a starting configuration. Renovate wants to create the configuration file (`renovate.json`) under the root path. I suggest you move it to the `.github` folder once the PR is merged. Renovate also supports the `.json5` format, which allows for comments and some other things.

Congratulations, you know have Renovate running :tada:

#### Private Github packages
We can use the default `GITHUB_TOKEN` to access private packages. The tedious part is passing this token to your Renovate config. We can pass it through a Renovate environment variable, which will create a Renovate `Host Rule`. Add the following to the `renovate.yaml` workflow file:

```yaml
RENOVATE_HOST_RULES: |
    [{"hostType": "docker", "matchHost": "ghcr.io", "username": "${{ github.actor }}", "password": "${{ secrets.GITHUB_TOKEN }}"}]
```

I'll set the `username` to `github.actor` which points back to my user. And then pass the defualt github token as the password. We need to set the packages permission for the token, which is done by settig the `permissions` key in the workflow file.

Renovate should now be able to read your private packages.

## My Renovate Config
The Renovate configuration is the sole place you can configure Renovate. It can get quite large, so it's a good idea to split it up into smaller sections. You can then reference all the individual parts in the `extends` field, using a list.

Below I've pasted my configuration file(s). Here the first ten keys after `extends`, are general settings that configure looks and other global settings.

In the next three sections I define paths for the build-in Managers for `flux`, `helm` and `kubernetes`. The build-in Managers should work out of the box. The `fileMatch` sets the path Renovate should look at for these types of resources. Renovate uses standard Regex. Regex can be quite tough to parse, I generally use online tools like [regex101](https://regex101.com) to test my Regex.

The last section sets some packageRules, that tells Renovate to add labels to the PR based on the type of update and what kind of resource it is.

```json
// .github/renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "github>chrede88/home-ops//.github/renovate/grafanadashboards.json",
    "github>chrede88/home-ops//.github/renovate/groups.json"
  ],
  "dependencyDashboardTitle": "Renovate Dashboard 🤖",
  "commitMessagePrefix": "🤖",
  "commitMessageTopic": "{{depName}}",
  "commitMessageExtra": "to {{newVersion}}",
  "commitMessageSuffix": "",
  "prConcurrentLimit": 0,
  "prHourlyLimit": 0,
  "reviewers": ["chrede88"],
  "timezone": "Europe/Zurich",
  "ignorePaths": ["/docs/*", "/network/*", "**/qubt/**", "**/l1nkr/**"],
  "flux": {
    "fileMatch": ["(^|/)cluster/kubernetes/.+\\.ya?ml"]
  },
  "helm-values": {
    "fileMatch": ["(^|/)cluster/kubernetes/.+\\.ya?ml$"]
  },
  "kubernetes": {
    "fileMatch": ["(^|/)cluster/kubernetes/.+\\.ya?ml$"]
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

The configuration below defines a special Manager (called a customManager) that looks for Grafana dashboards updates. Because these updates don't conform to any standard naming schemes, I need a customManager. The basic idea is that we can help Renovate by providing some information that points Renovate to where the dashboards are kept. We do this by adding comments in the resource definitions and then defining a Regex that match the comment plus the part of the manifest that define the current version.

Looking at my [Grafana helm release](../cluster/kubernetes/observability/grafana/app/helmrelease.yaml), helps to understand the idea.
The following a single dashboard definition:
```yaml
node-exporter-full:
  # renovate: depName="Node Exporter Full"
  gnetId: 1860
  revision: 37
```

Notice how the defined `matchStrings` in the `customManager` below matches the comment plus the `getId` and `revision` keys. This allows Renovate to extract the current version of this dashboard, which it can then compare using the defined `defaultRegistryUrlTemplate`. You can read more about customManagers [here](https://docs.renovatebot.com/configuration-options/#custommanagers).

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

The last part of my configuration defines two `groups`. Groups tell Renovate to create a single PR for all the resources defined in the group. This is useful if you have resources spred over more than one helm release.

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

## Other github work flows
Another Github Action that I find very useful is to use `flux-diff` to generate nice git diffs for each new PR.

```yaml
# .github/workflows/flux-diff.yaml
name: "Flux Diff"

on:
  pull_request:
    branches: ["main"]
    paths: ["cluster/kubernetes/**"]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.number || github.ref }}
  cancel-in-progress: true

permissions:
  pull-requests: write

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
        uses: fluxcd/flux2/action@v2.4.0
      - uses: allenporter/flux-local/action/diff@6.0.0
        id: diff
        with:
          live-branch: main
          path: cluster/kubernetes/flux/main
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
```