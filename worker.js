const Redis = require('ioredis');
const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

// ═══════════════════════════════════════════════════════════════
// CLAUDE AUTH BYPASS (HEADLESS)
// ═══════════════════════════════════════════════════════════════

function setupClaudeAuthBypass() {
  try {
    const homeDir = os.homedir();

    // 1) Onboarding file to prevent browser / interactive flow
    const onboardingPath = path.join(homeDir, '.claude.json');
    const onboardingPayload = {
      hasCompletedOnboarding: true,
      theme: 'dark'
    };

    try {
      // Try to preserve other fields if the file already exists
      const existing = fs.readFileSync(onboardingPath, 'utf-8');
      let data = {};
      try {
        data = JSON.parse(existing);
      } catch {
        data = {};
      }
      data.hasCompletedOnboarding = true;
      if (!data.theme) data.theme = 'dark';
      fs.writeFileSync(onboardingPath, JSON.stringify(data, null, 2));
    } catch {
      // If the file does not exist (or fails to read), create from scratch
      fs.writeFileSync(onboardingPath, JSON.stringify(onboardingPayload, null, 2));
    }

    // 2) Credentials based on CLAUDE_CODE_OAUTH_TOKEN (headless)
    const token = process.env.CLAUDE_CODE_OAUTH_TOKEN;
    if (token) {
      const claudeDir = path.join(homeDir, '.claude');
      const credentialsPath = path.join(claudeDir, '.credentials.json');

      if (!fs.existsSync(claudeDir)) {
        fs.mkdirSync(claudeDir, { recursive: true });
      }

      const credentials = {
        claudeAiOauth: {
          accessToken: token,
          refreshToken: token,
          expiresAt: 9999999999999,
          scopes: ['user:inference', 'user:profile']
        }
      };

      fs.writeFileSync(credentialsPath, JSON.stringify(credentials, null, 2));
    }
  } catch (err) {
    console.error('Failed to setup Claude auth bypass:', err.message);
  }
}

// Run auth bypass on boot before any CLI calls.
setupClaudeAuthBypass();

const redis = new Redis(process.env.REDIS_URL);
const WORKER_NAME = process.env.WORKER_NAME || os.hostname();
const WORKER_ID = `${WORKER_NAME}-${process.pid}`;
const REPOS_DIR = process.env.REPOS_DIR || '/home/worker/repos';

console.log(`Worker ${WORKER_ID} started (generic skill executor)`);
console.log(`Worker Name: ${WORKER_NAME}`);
console.log(`Repos: ${REPOS_DIR}`);

if (!fs.existsSync(REPOS_DIR)) {
  fs.mkdirSync(REPOS_DIR, { recursive: true });
}

function exec(cmd, options = {}) {
  const displayCmd = cmd.length > 100 ? cmd.substring(0, 100) + '...' : cmd;
  console.log(`  $ ${displayCmd}`);
  try {
    return execSync(cmd, {
      encoding: 'utf-8',
      timeout: options.timeout || 1800000,
      maxBuffer: 50 * 1024 * 1024,
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { 
        ...process.env, 
        HOME: '/home/worker', 
        USER: 'worker',
        PATH: process.env.PATH // Keep path to find git/claude
      },
      shell: true,
      ...options
    });
  } catch (error) {
    console.error(`  [ERROR] Command failed: ${error.message}`);
    if (error.stderr) console.error(`  STDERR: ${error.stderr}`);
    if (error.stdout) console.error(`  STDOUT: ${error.stdout}`);
    throw error;
  }
}

// Check Claude CLI is working
function checkClaudeAuth() {
  try {
    const version = execSync('claude --version', { encoding: 'utf-8', timeout: 10000 });
    console.log(`Claude CLI: ${version.trim()}`);
    return true;
  } catch (e) {
    console.error('Claude CLI not available or not authenticated!');
    console.error(e.message);
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════
// GIT HELPERS
// ═══════════════════════════════════════════════════════════════

function setupRepo(repoUrl, taskId, branch) {
  const repoName = repoUrl.split('/').pop().replace('.git', '');
  const repoPath = path.join(REPOS_DIR, `${repoName}-${taskId}`);
  
  console.log(`  Repo: ${repoPath}`);

  if (fs.existsSync(repoPath)) {
    console.log(`  Updating existing repo...`);
    try {
      execSync(`git reset --hard`, { cwd: repoPath, encoding: 'utf-8' });
      execSync(`git clean -fd`, { cwd: repoPath, encoding: 'utf-8' });
    } catch {}
    
    try {
      exec(`git fetch origin`, { cwd: repoPath });
      exec(`git checkout main && git pull origin main`, { cwd: repoPath });
    } catch (e) {
      try {
        exec(`git checkout master && git pull origin master`, { cwd: repoPath });
      } catch (e2) {
        console.log(`  [WARN] Could not update from main/master`);
      }
    }
  } else {
    console.log(`  Cloning repository...`);
    exec(`git clone ${repoUrl} ${repoPath}`);
  }

  // Checkout or create branch
  try {
    exec(`git checkout ${branch}`, { cwd: repoPath });
    console.log(`  Checked out ${branch}`);
    try {
      exec(`git pull origin ${branch}`, { cwd: repoPath });
    } catch (e) {}
  } catch {
    exec(`git checkout -b ${branch}`, { cwd: repoPath });
    console.log(`  Created branch ${branch}`);
  }

  return repoPath;
}

function commitAndPush(repoPath, taskId, agent) {
  exec(`git add -A`, { cwd: repoPath });

  let hasChanges = false;
  let filesModified = [];
  
  try {
    const status = execSync(`git status --porcelain`, { cwd: repoPath, encoding: 'utf-8' });
    hasChanges = status.trim().length > 0;
  } catch (e) {}

  if (hasChanges) {
    try {
      exec(`git commit --no-verify -m "feat(${taskId}): implementation by ${agent}"`, { cwd: repoPath });
      exec(`git push -u origin HEAD`, { cwd: repoPath });
      console.log(`  Changes committed and pushed`);
      try {
        const diff = execSync(`git diff --name-only HEAD~1 HEAD`, { cwd: repoPath, encoding: 'utf-8' });
        filesModified = diff.trim().split('\n').filter(Boolean);
      } catch (e) {}
    } catch (e) {
      console.log(`  [WARN] Commit/push failed: ${e.message}`);
    }
  } else {
    console.log(`  No changes to commit`);
  }

  return { hasChanges, filesModified };
}

// ═══════════════════════════════════════════════════════════════
// AGENT EXECUTION
// ═══════════════════════════════════════════════════════════════

function runAgent(agent, promptFile, cwd) {
  // Claude and Gemini both receive input via stdin pipe
  // Using same format as old working worker
  // Note: shell: true is needed for pipe operator
  const execOpts = { 
    cwd, 
    encoding: 'utf-8',
    timeout: 1800000,
    maxBuffer: 50 * 1024 * 1024,
    shell: true
  };
  
  let cmd;
  if (agent === 'gemini-cli') {
    cmd = `cat "${promptFile}" | gemini --output-format json`;
  } else {
    // Default: claude-code
    cmd = `cat "${promptFile}" | claude --output-format json --dangerously-skip-permissions`;
  }
  
  console.log(`  $ ${cmd.substring(0, 80)}...`);
  
  try {
    return execSync(cmd, execOpts);
  } catch (error) {
    console.error(`  [ERROR] Agent command failed`);
    console.error(`  STDERR: ${error.stderr || 'none'}`);
    console.error(`  STDOUT: ${error.stdout || 'none'}`);
    throw error;
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN JOB PROCESSOR
// ═══════════════════════════════════════════════════════════════

async function processJob(job) {
  const { id, type, skills, context, metadata } = job;
  const startTime = Date.now();
  
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`Processing job: ${id}`);
  console.log(`Type: ${type}`);
  console.log(`Skills: ${(skills || []).map(s => s.name).join(', ')}`);
  console.log(`${'═'.repeat(60)}`);

  // Determine working directory
  let cwd;
  let repoPath = null;
  const useGit = metadata?.repoUrl && metadata?.branch;
  
  if (useGit) {
    // Dev pipeline: use git repo
    repoPath = setupRepo(metadata.repoUrl, metadata.taskId, metadata.branch);
    cwd = repoPath;
  } else {
    // Validation pipeline: use temp directory
    cwd = path.join(os.tmpdir(), `worker-${id}-${Date.now()}`);
    fs.mkdirSync(cwd, { recursive: true });
  }

  try {
    // ─────────────────────────────────────────────────────────────
    // BUILD PROMPT
    // Concatenate: skills + context into single prompt file
    // ─────────────────────────────────────────────────────────────
    let prompt = '';
    
    // Add each skill
    for (const skill of (skills || [])) {
      prompt += `# SKILL: ${skill.name}\n\n`;
      prompt += skill.content;
      prompt += '\n\n---\n\n';
    }
    
    // Add context
    prompt += '# CONTEXT\n\n';
    prompt += context || '';
    
    // Write to prompt file
    const promptFile = path.join(cwd, '.prompt.md');
    fs.writeFileSync(promptFile, prompt);
    
    console.log(`  Prompt file: ${promptFile} (${prompt.length} chars)`);

    // ─────────────────────────────────────────────────────────────
    // RUN AGENT
    // ─────────────────────────────────────────────────────────────
    const agent = metadata?.agent || 'claude-code';
    console.log(`  Running ${agent}...`);
    
    let output;
    let agentFailed = false;
    
    try {
      output = runAgent(agent, promptFile, cwd);
    } catch (error) {
      console.error(`  Agent error: ${error.message}`);
      agentFailed = true;
      output = error.stdout || error.message;
    }
    
    // Cleanup prompt file
    try { fs.unlinkSync(promptFile); } catch {}

    // ─────────────────────────────────────────────────────────────
    // GIT: COMMIT & PUSH (if dev pipeline)
    // ─────────────────────────────────────────────────────────────
    let gitInfo = null;
    
    if (useGit && repoPath) {
      gitInfo = commitAndPush(repoPath, metadata.taskId, agent);
    }

    // ─────────────────────────────────────────────────────────────
    // PARSE OUTPUT
    // ─────────────────────────────────────────────────────────────
    let parsedOutput;
    try {
      parsedOutput = JSON.parse(output);
    } catch {
      parsedOutput = { raw: output };
    }

    const duration = Date.now() - startTime;
    console.log(`  Completed in ${Math.round(duration / 1000)}s`);

    return {
      success: !agentFailed,
      output: parsedOutput,
      gitInfo,
      duration,
      workerName: WORKER_NAME
    };

  } catch (error) {
    console.error(`  Job failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      duration: Date.now() - startTime,
      workerName: WORKER_NAME
    };
  } finally {
    // Cleanup temp directory (only for validation jobs)
    if (!useGit && cwd && cwd.startsWith(os.tmpdir())) {
      try {
        fs.rmSync(cwd, { recursive: true, force: true });
      } catch {}
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════

async function main() {
  await redis.ping();
  console.log('Connected to Redis');
  
  // Check Claude is working
  if (!checkClaudeAuth()) {
    console.error('Exiting due to Claude CLI issue');
    process.exit(1);
  }
  
  console.log('Waiting for jobs on JOB_QUEUE...\n');
  
  while (true) {
    try {
      const result = await redis.blpop('JOB_QUEUE', 0);
      if (!result) continue;
      
      const job = JSON.parse(result[1]);
      console.log(`\nReceived job: ${job.id} (${job.type})`);
      
      // Mark as processing
      await redis.hset('PROCESSING', job.id, JSON.stringify({
        workerId: WORKER_ID,
        workerName: WORKER_NAME,
        startedAt: Date.now(),
        type: job.type
      }));
      
      // Process the job
      const jobResult = await processJob(job);
      
      // Publish result
      await redis.publish('JOB_RESULTS', JSON.stringify({
        ...jobResult,
        jobId: job.id,
        type: job.type,
        metadata: job.metadata,
        workerId: WORKER_ID
      }));
      
      // Remove from processing
      await redis.hdel('PROCESSING', job.id);
      
      console.log(`Job ${job.id} completed (success: ${jobResult.success})`);
      
    } catch (error) {
      console.error(`Main loop error: ${error.message}`);
      await new Promise(r => setTimeout(r, 5000));
    }
  }
}

main();