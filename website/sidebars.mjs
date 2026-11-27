export default {
  docs: [
    "index",
    "install",
    "wrapper",
    "auth",
    "configuration",
    {
      type: "category",
      label: "Modes",
      link: { type: "doc", id: "modes" },
      items: [
        "modes/api",
        "modes/telegram",
        "modes/cron",
        "modes/mcp",
      ],
    },
    "codex-adapter",
    "agents",
    "troubleshooting",
    "development",
  ],
};
