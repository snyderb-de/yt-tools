const metrics = [
  { label: "MVP tasks complete", value: "14 / 14" },
  { label: "Core blockers", value: "0" },
  { label: "Next milestone", value: "Queue" },
  { label: "Release target", value: "Alpha" }
];

const roadmap = {
  now: [
    { text: "Add unit tests for command argument builders", className: "" },
    { text: "Map common yt-dlp errors to friendlier messages", className: "" },
    { text: "Smoke-test dark/light themes in both frontends", className: "" }
  ],
  next: [
    { text: "Multi-job queue and cancellation model", className: "" },
    { text: "Playlist selective download flow", className: "" },
    { text: "Batch URL import", className: "" }
  ],
  later: [
    { text: "Subscription management panel", className: "" },
    { text: "Auto-download rules", className: "" },
    { text: "Bulk action center", className: "" }
  ],
  done: [
    { text: "SwiftUI desktop MVP scaffolded", className: "done" },
    { text: "Go TUI migrated to Charm stack", className: "done" },
    { text: "yt-dlp + ffmpeg execution pipeline", className: "done" },
    { text: "Auth passthrough modes in UI", className: "done" },
    { text: "URL-list-file bulk mode in app", className: "done" },
    { text: "Live network throughput graph in all apps", className: "done" },
    { text: "Input validation messaging improvements", className: "done" },
    { text: "Preset save/load for format/output/auth", className: "done" },
    { text: "Settings persistence in Swift + Go frontends", className: "done" }
  ]
};

const actionPlan = [
  {
    track: "App Shell",
    goal: "Create desktop UI for single job flow",
    status: "done",
    notes: "Form, mode controls, auth panel, logs"
  },
  {
    track: "Execution Engine",
    goal: "Run yt-dlp with ffmpeg conversion options",
    status: "done",
    notes: "Asynchronous process runner with streaming output"
  },
  {
    track: "Auth",
    goal: "Support private/restricted content flows",
    status: "done",
    notes: "Browser cookies and cookies.txt wired in both frontends"
  },
  {
    track: "Reliability",
    goal: "Improve failures and cancellation reporting",
    status: "progress",
    notes: "Validation + warnings shipped; extractor-specific error mapping remains"
  },
  {
    track: "Batch",
    goal: "Playlist + queue architecture",
    status: "todo",
    notes: "Phase 2 target"
  }
];

const risks = [
  "Browser cookie extraction behavior differs by browser and macOS permissions.",
  "YouTube extractor changes can break specific URLs until yt-dlp updates.",
  "Large conversions can stress disk space and system resources."
];

const todos = [
  "Write tests for argument generation per mode/auth combination.",
  "Define queue data model before playlist feature work starts.",
  "Add playlist URL ingestion with selective include/exclude controls.",
  "Package signed macOS app bundle and stage release workflow."
];

function renderMetrics() {
  const container = document.getElementById("metrics");
  container.innerHTML = metrics
    .map(
      (item) => `
      <article class="metric-card">
        <div class="label">${item.label}</div>
        <div class="value">${item.value}</div>
      </article>
    `
    )
    .join("");
}

function renderRoadmap() {
  const container = document.getElementById("roadmap");
  const columns = [
    { key: "done", title: "Done" },
    { key: "now", title: "Now" },
    { key: "next", title: "Next" },
    { key: "later", title: "Later" }
  ];

  container.innerHTML = columns
    .map(({ key, title }) => {
      const cards = roadmap[key]
        .map((item) => `<div class="card ${item.className || ""}">${item.text}</div>`)
        .join("");

      return `<article class="column"><h3>${title}</h3>${cards}</article>`;
    })
    .join("");
}

function renderActionPlan() {
  const tbody = document.getElementById("action-plan");
  tbody.innerHTML = actionPlan
    .map(
      (item) => `
      <tr>
        <td>${item.track}</td>
        <td>${item.goal}</td>
        <td><span class="tag ${item.status}">${item.status}</span></td>
        <td>${item.notes}</td>
      </tr>
    `
    )
    .join("");
}

function renderList(id, items, className = "") {
  const container = document.getElementById(id);
  container.innerHTML = items
    .map((item) => `<li class="${className}">${item}</li>`)
    .join("");
}

function setUpdateTime() {
  const el = document.getElementById("updated-at");
  const now = new Date();
  el.textContent = now.toLocaleString();
}

renderMetrics();
renderRoadmap();
renderActionPlan();
renderList("risks", risks, "risk");
renderList("todos", todos, "todo");
setUpdateTime();
