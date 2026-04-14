const metrics = [
  { label: "MVP tasks complete", value: "12 / 14" },
  { label: "Core blockers", value: "1" },
  { label: "Next milestone", value: "Queue" },
  { label: "Release target", value: "Alpha" }
];

const roadmap = {
  now: [
    { text: "Harden URL + auth validation", className: "" },
    { text: "Persist settings and last-used output", className: "" },
    { text: "Add command-builder unit tests", className: "" }
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
    { text: "Live network throughput graph in all apps", className: "done" }
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
    status: "progress",
    notes: "Browser cookies and cookies.txt in place; error messaging next"
  },
  {
    track: "Reliability",
    goal: "Improve failures and cancellation reporting",
    status: "todo",
    notes: "Map common yt-dlp errors into friendlier UI messages"
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
  "Implement app settings persistence for defaults and recent output paths.",
  "Add validation for missing cookies.txt path when file auth is selected.",
  "Write tests for argument generation per mode/auth combination.",
  "Define queue data model before playlist feature work starts."
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
