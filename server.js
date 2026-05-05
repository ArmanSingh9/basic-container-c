/**
 * server.js — BasicContainer Web API
 * Node.js + Express backend that bridges the C container binary
 * to the frontend dashboard.
 */

const path = require("path");
const express = require("express");
const cors = require("cors");
const { spawn } = require("child_process");

// Minimal comment: this server runs commands inside the container via the web UI

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));  // serves index.html, css, etc.

// ─── In-memory command history ───────────────────────────────
const commandHistory = [];
const MAX_HISTORY = 100;

// ─── Health check ────────────────────────────────────────────
app.get("/api/status", (req, res) => {
  res.json({
    status: "online",
    uptime: process.uptime(),
    platform: process.platform,
    nodeVersion: process.version,
    historyCount: commandHistory.length,
    timestamp: new Date().toISOString()
  });
});

// ─── Run a command ───────────────────────────────────────────
app.post("/api/run", (req, res) => {
  const userInput = (req.body.command || "").trim();

  if (!userInput) {
    return res.json({ success: false, output: null, error: "Empty command.", command: userInput });
  }

  const startTime = Date.now();

  // We wrap the command in bash -c to support shell built-ins like 'cd' and 'history'
  // and pipes/redirects if the user tries them.
  // Example: sudo ./container run /bin/bash -c "ls -la"
  const spawnArgs = ["./container", "run", "/bin/bash", "-c", userInput];

  const child = spawn("sudo", spawnArgs, { cwd: __dirname });

  let stdout = "";
  let stderr = "";

  child.stdout.on("data", (d) => { stdout += d.toString(); });
  child.stderr.on("data", (d) => { stderr += d.toString(); });

  child.on("close", (code) => {
    const elapsed = Date.now() - startTime;
    const success = code === 0;

    // Filter out internal [HOST] / [CONTAINER] prefix lines for cleaner display if they exist
    // (though we removed most of them in container.c to keep it clean)
    const cleanOutput = stdout.trim();

    const entry = {
      command: userInput,
      success,
      output: cleanOutput || (stderr ? null : "(no output)"),
      error: stderr || (success ? null : `Exit code: ${code}`),
      exitCode: code,
      elapsed,
      timestamp: new Date().toISOString()
    };

    commandHistory.unshift(entry);
    if (commandHistory.length > MAX_HISTORY) commandHistory.pop();

    res.json(entry);
  });

  child.on("error", (err) => {
    const entry = {
      command: userInput,
      success: false,
      output: null,
      error: `Failed to start process: ${err.message}. Make sure './container' binary exists and you are on Linux.`,
      timestamp: new Date().toISOString()
    };
    commandHistory.unshift(entry);
    res.json(entry);
  });
});

// ─── History ─────────────────────────────────────────────────
app.get("/api/history", (req, res) => {
  res.json({ history: commandHistory });
});

// ─── Clear history ───────────────────────────────────────────
app.delete("/api/history", (req, res) => {
  commandHistory.length = 0;
  res.json({ success: true, message: "History cleared." });
});

// ─── Start server ─────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n  ╔══════════════════════════════════════════╗`);
  console.log(`  ║   BasicContainer Web API — Node.js       ║`);
  console.log(`  ╚══════════════════════════════════════════╝`);
  console.log(`\n  🟢 Server running at http://localhost:${PORT}`);
  console.log(`  📋 API endpoints:`);
  console.log(`       GET  /api/status`);
  console.log(`       POST /api/run      { command: "ls" }`);
  console.log(`       GET  /api/history`);
  console.log(`       DEL  /api/history\n`);
});
