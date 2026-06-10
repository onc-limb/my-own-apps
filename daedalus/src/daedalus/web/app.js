/* daedalus 操作パネル */

const $ = (sel) => document.querySelector(sel);

const SPEC_TEMPLATE = `name: my-stack
provider: aws
region: ap-northeast-1

description: |
  - 作りたいインフラを自然言語で書く

constraints:
  - できるだけ低コストに収める

# プロジェクトの GitHub リポジトリ（任意）
# owner は環境変数 GITHUB_OWNER でも指定可能
# github:
#   repo: my-infra-project
#   branch: main

terraform:
  required_version: ">= 1.5.0"
  backend: local
`;

let currentRunId = null;
let eventSource = null;

/* ---------- 初期化 ---------- */

async function init() {
  $("#spec").value = SPEC_TEMPLATE;
  await refreshEnv();
  await refreshHistory();
  $("#start").addEventListener("click", startRun);
  $("#refresh-history").addEventListener("click", refreshHistory);
  $("#gh-pull").addEventListener("click", () => githubOp("pull"));
  $("#gh-push").addEventListener("click", () => githubOp("push"));
}

async function refreshEnv() {
  try {
    const env = await (await fetch("/api/env")).json();
    const badge = (label, ok) =>
      `<span class="badge ${ok ? "ok" : "ng"}">${label}: ${ok ? "✓" : "✗"}</span>`;
    $("#env-badges").innerHTML =
      badge("ANTHROPIC_API_KEY", env.anthropic_api_key) +
      badge("GITHUB_TOKEN", env.github_token) +
      badge("GITHUB_OWNER", env.github_owner);
  } catch { /* server down — leave blank */ }
}

/* ---------- Run 開始・イベント購読 ---------- */

async function startRun() {
  $("#start-error").textContent = "";
  const body = {
    spec_yaml: $("#spec").value,
    mode: document.querySelector('input[name="mode"]:checked').value,
    workspace: $("#workspace").value || null,
    model: $("#model").value || null,
    max_turns: parseInt($("#max-turns").value, 10) || 40,
    allow_destroy: $("#opt-destroy").checked,
    pull: $("#opt-pull").checked,
    push: $("#opt-push").checked,
  };
  const resp = await fetch("/api/runs", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await resp.json();
  if (!resp.ok) {
    $("#start-error").textContent = data.detail || "実行に失敗しました";
    return;
  }
  $("#log").innerHTML = "";
  $("#approval-area").innerHTML = "";
  subscribe(data.run_id);
  refreshHistory();
}

function subscribe(runId) {
  if (eventSource) eventSource.close();
  currentRunId = runId;
  setStatus("running");
  eventSource = new EventSource(`/api/runs/${runId}/events`);
  eventSource.onmessage = (msg) => handleEvent(JSON.parse(msg.data));
  eventSource.onerror = () => { /* 再接続は EventSource 任せ */ };
}

function setStatus(status) {
  const el = $("#run-status");
  el.textContent = status ? `[${status}]` : "";
  el.className = status;
}

function addLog(cls, text) {
  const div = document.createElement("div");
  div.className = `ev ${cls}`;
  div.textContent = text;
  const log = $("#log");
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
}

function handleEvent(ev) {
  switch (ev.kind) {
    case "run_start":
      addLog("github", `▶ run 開始 — ${ev.spec} [${ev.mode}] @ ${ev.workspace}`);
      break;
    case "assistant_text":
      addLog("assistant", ev.text);
      break;
    case "tool_use":
      addLog("tool", `⏵ ${ev.tool}: ${ev.input}`);
      break;
    case "bash_pre":
      if (ev.decision === "deny") addLog("denied", `⛔ denied: ${ev.command} — ${ev.reason}`);
      break;
    case "approval_pending":
      showApproval(ev);
      addLog("denied", `⏸ 承認待ち: ${ev.command}`);
      break;
    case "approval_decision":
      addLog(ev.approved ? "end" : "denied",
        ev.approved ? `✅ 承認されました: ${ev.command}` : `❌ 却下されました: ${ev.command}`);
      break;
    case "github_pull_start": addLog("github", `⬇ GitHub pull: ${ev.repo}@${ev.branch}`); break;
    case "github_pull_done": addLog("github", `⬇ pull 完了 (${ev.files} files)`); break;
    case "github_push_start": addLog("github", `⬆ GitHub push: ${ev.repo}@${ev.branch}`); break;
    case "github_push_done": addLog("github", `⬆ push 完了 ${ev.sha?.slice(0, 7)} (${ev.files} files) ${ev.url || ""}`); break;
    case "result":
      if (ev.cost_usd != null) addLog("tool", `💰 cost: $${Number(ev.cost_usd).toFixed(4)}`);
      break;
    case "run_end":
      addLog("end", `■ run 終了 — succeeded=${ev.succeeded} (plan=${ev.plan_ok}, apply=${ev.apply_ok}, denied=${ev.denied_calls})`);
      break;
    case "run_error":
      addLog("error", `‼ エラー: ${ev.error}`);
      break;
    case "stream_end":
      setStatus(ev.status || "done");
      $("#approval-area").innerHTML = "";
      if (eventSource) eventSource.close();
      refreshHistory();
      break;
  }
}

/* ---------- 承認カード ---------- */

function showApproval(ev) {
  const area = $("#approval-area");
  const card = document.createElement("div");
  card.className = "approval-card";
  card.innerHTML = `
    <h3>⏸ 承認が必要です</h3>
    <div>コマンド: <span class="cmd"></span></div>
    <div class="hint"></div>
    <pre></pre>
    <div class="actions">
      <button class="approve">✅ 承認して実行</button>
      <button class="reject">❌ 却下</button>
    </div>`;
  card.querySelector(".cmd").textContent = ev.command;
  card.querySelector(".hint").textContent = ev.reason || "";
  card.querySelector("pre").textContent = ev.context_tail || "(直前の terraform 出力なし)";
  const resolve = async (approved) => {
    await fetch(`/api/approvals/${ev.approval_id}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ approved }),
    });
    card.remove();
  };
  card.querySelector(".approve").addEventListener("click", () => resolve(true));
  card.querySelector(".reject").addEventListener("click", () => resolve(false));
  area.appendChild(card);
}

/* ---------- 履歴 ---------- */

async function refreshHistory() {
  try {
    const runs = await (await fetch("/api/runs")).json();
    const root = $("#history");
    root.innerHTML = runs.length ? "" : '<div class="muted hint">まだ実行はありません</div>';
    for (const r of runs) {
      const item = document.createElement("div");
      item.className = "item";
      const cost = r.cost_usd != null ? `$${Number(r.cost_usd).toFixed(4)}` : "";
      item.innerHTML = `
        <span class="status ${r.status}">${r.status}</span>
        <b></b><span class="muted">[${r.mode}]</span>
        <span class="muted ws"></span><span class="muted">${cost}</span>
        <button class="small">ログ</button>`;
      item.querySelector("b").textContent = r.spec_name;
      item.querySelector(".ws").textContent = r.workspace;
      item.querySelector("button").addEventListener("click", () => {
        $("#log").innerHTML = "";
        $("#approval-area").innerHTML = "";
        subscribe(r.id);
      });
      root.appendChild(item);
    }
  } catch { /* ignore */ }
}

/* ---------- GitHub 手動操作 ---------- */

async function githubOp(op) {
  const out = $("#gh-result");
  out.textContent = "実行中…";
  const body = {
    spec_yaml: $("#spec").value,
    workspace: $("#gh-workspace").value || guessWorkspace(),
  };
  const resp = await fetch(`/api/github/${op}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await resp.json();
  if (!resp.ok) { out.textContent = `エラー: ${data.detail}`; return; }
  out.textContent = op === "pull"
    ? `⬇ ${data.repo}@${data.branch} から ${data.files} files 取得`
    : `⬆ ${data.repo}@${data.branch} へ push 完了 (${data.sha?.slice(0, 7)}, ${data.files} files)`;
}

function guessWorkspace() {
  const m = $("#spec").value.match(/^name:\s*(\S+)/m);
  return m ? `workspace/${m[1]}` : "workspace";
}

init();
