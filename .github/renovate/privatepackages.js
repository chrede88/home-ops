hostRules: [
  {
    matchHost: "ghcr.io/chrede88/",
    hostType: "docker",
    username: process.env.RENOVATE_BOT_NAME,
    password: process.env.RENOVATE_GITHUB_TOKEN,
  },
];
