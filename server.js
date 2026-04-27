const path = require("path");
const express = require("express");
const cors = require("cors");
const { spawn } = require("child_process");

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));

// 🔐 Allowed commands (whitelist)
const ALLOWED_COMMANDS = {
"echo": "/bin/echo",
"ls": "/bin/ls",
"bash": "/bin/bash",
"cat": "/bin/cat",
"touch": "/bin/touch",
"pwd": "/bin/pwd"
};

// 📜 Command history
const commandHistory = [];

app.post("/run", (req, res) => {
const userCommand = req.body.command;

if (!userCommand || typeof userCommand !== "string" || userCommand.trim() === "") {
return res.json({ success: false, output: null, error: "Empty or invalid command." });
}

// 🧠 Parse command
const parts = userCommand.trim().split(/\s+/);
const baseCmd = parts[0];
const args = parts.slice(1);

// 🔐 Security check
if (!ALLOWED_COMMANDS[baseCmd]) {
const errorMsg = `Command '${baseCmd}' is not permitted. Allowed: ${Object.keys(ALLOWED_COMMANDS).join(", ")}`;
commandHistory.push({ command: userCommand, success: false, timestamp: new Date() });
return res.json({ success: false, output: null, error: errorMsg });
}

// ⚡ Detect shell features
const needsShell = userCommand.includes(">") || userCommand.includes("|") || userCommand.includes("&&");

let child;

if (needsShell) {
// ⚡ Shell mode (supports >, |, etc.)
const fullCommand = `sudo ./container run ${ALLOWED_COMMANDS[baseCmd]} ${args.join(" ")}`;
child = spawn("sh", ["-c", fullCommand]);
} else {
// 🔒 Safe mode
const spawnArgs = [
"./container",
"run",
ALLOWED_COMMANDS[baseCmd],
...args
];
child = spawn("sudo", spawnArgs);
}

let stdoutData = "";
let stderrData = "";

child.stdout.on("data", (data) => {
stdoutData += data.toString();
});

child.stderr.on("data", (data) => {
stderrData += data.toString();
});

child.on("close", (code) => {
  const success = code === 0;

  const errorMsg = stderrData
    ? stderrData
    : (success ? null : `Process exited with code ${code}`);

  // 📜 Save history
  commandHistory.push({
    command: userCommand,
    success: success,
    timestamp: new Date()
  });

  res.json({
    success: success,
    output: stdoutData,
    error: errorMsg
  });
});

}); // ✅ CLOSE app.post HERE

// 📜 Optional history API
app.get("/history", (req, res) => {
  res.json({ history: commandHistory });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});