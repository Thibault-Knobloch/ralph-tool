#!/usr/bin/env node

const { program } = require('commander');
const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const chalk = require('chalk');

// Colors matching culinary cloud style
const cmd = chalk.bold.magenta;
const title = chalk.bold.cyan;
const dim = chalk.dim;

// Resolve paths
const RALPH_HOME = path.resolve(__dirname, '..');
const PROJECT_DIR = process.cwd();
const PROJECT_RALPH_DIR = path.join(PROJECT_DIR, '.ralph');

// Set environment variables for child scripts
process.env.RALPH_HOME = RALPH_HOME;
process.env.PROJECT_DIR = PROJECT_DIR;
process.env.PROJECT_RALPH_DIR = PROJECT_RALPH_DIR;

// Helper: Check if .ralph exists
function requireInit() {
  if (!fs.existsSync(PROJECT_RALPH_DIR)) {
    console.error(chalk.red('Error: .ralph/ not found in current directory'));
    console.log('');
    console.log("Run 'ralph init' first to initialize Ralph in this project.");
    process.exit(1);
  }
}

// Helper: Run a bash script (async — for non-interactive commands)
function runScript(scriptName, args = []) {
  const scriptPath = path.join(RALPH_HOME, 'scripts', scriptName);

  if (!fs.existsSync(scriptPath)) {
    console.error(chalk.red(`Error: Script not found: ${scriptPath}`));
    process.exit(1);
  }

  const child = spawn('bash', [scriptPath, ...args], {
    stdio: 'inherit',
    env: { ...process.env, RALPH_HOME, PROJECT_DIR, PROJECT_RALPH_DIR }
  });

  child.on('close', (code) => {
    process.exit(code || 0);
  });
}

// Helper: Run a bash script synchronously (for interactive/TTY commands like sandbox)
function runScriptSync(scriptName, args = []) {
  const scriptPath = path.join(RALPH_HOME, 'scripts', scriptName);

  if (!fs.existsSync(scriptPath)) {
    console.error(chalk.red(`Error: Script not found: ${scriptPath}`));
    process.exit(1);
  }

  const result = spawnSync('bash', [scriptPath, ...args], {
    stdio: 'inherit',
    env: { ...process.env, RALPH_HOME, PROJECT_DIR, PROJECT_RALPH_DIR }
  });

  process.exit(result.status || 0);
}

// Helper: Copy directory recursively
function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// Init command
function doInit() {
  if (fs.existsSync(PROJECT_RALPH_DIR)) {
    console.log(chalk.yellow('Warning: .ralph/ already exists in this directory'));
    const readline = require('readline');
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

    rl.question('Overwrite? (y/N) ', (answer) => {
      rl.close();
      if (answer.toLowerCase() !== 'y') {
        console.log('Aborted.');
        process.exit(0);
      }
      performInit();
    });
  } else {
    performInit();
  }
}

function performInit() {
  console.log(chalk.green(`Initializing Ralph in ${PROJECT_DIR}`));
  console.log('');

  // Create directory structure
  console.log('[1/3] Creating directory structure...');
  fs.mkdirSync(path.join(PROJECT_RALPH_DIR, 'config'), { recursive: true });
  fs.mkdirSync(path.join(PROJECT_RALPH_DIR, 'tasks', '1_new_tasks'), { recursive: true });
  fs.mkdirSync(path.join(PROJECT_RALPH_DIR, 'tasks', '2_done_tasks'), { recursive: true });
  fs.mkdirSync(path.join(PROJECT_RALPH_DIR, 'logs', 'progress'), { recursive: true });
  fs.mkdirSync(path.join(PROJECT_RALPH_DIR, 'roles'), { recursive: true });
  console.log(chalk.green('  ✓') + ' Directories created');

  // Copy templates
  console.log('[2/3] Copying templates...');
  const templatesDir = path.join(RALPH_HOME, 'templates');

  // Config files
  fs.copyFileSync(
    path.join(templatesDir, 'prompt.md'),
    path.join(PROJECT_RALPH_DIR, 'config', 'prompt.md')
  );
  fs.copyFileSync(
    path.join(templatesDir, 'AGENT.md'),
    path.join(PROJECT_RALPH_DIR, 'config', 'AGENT.md')
  );
  fs.copyFileSync(
    path.join(templatesDir, 'pr-review-prompt.md'),
    path.join(PROJECT_RALPH_DIR, 'config', 'pr-review-prompt.md')
  );

  // Task files
  fs.copyFileSync(
    path.join(templatesDir, 'testing-harness.md'),
    path.join(PROJECT_RALPH_DIR, 'tasks', 'testing-harness.md')
  );
  fs.copyFileSync(
    path.join(templatesDir, 'feature-spec-template.md'),
    path.join(PROJECT_RALPH_DIR, 'tasks', 'feature-spec-template.md')
  );
  fs.copyFileSync(
    path.join(templatesDir, 'prd.json'),
    path.join(PROJECT_RALPH_DIR, 'tasks', 'prd.json')
  );

  // Plan mode files
  fs.copyFileSync(
    path.join(templatesDir, 'vision.md'),
    path.join(PROJECT_RALPH_DIR, 'config', 'vision.md')
  );
  fs.copyFileSync(
    path.join(templatesDir, 'plan-prompt.md'),
    path.join(PROJECT_RALPH_DIR, 'config', 'plan-prompt.md')
  );
  fs.copyFileSync(
    path.join(templatesDir, 'plan-cleanup-prompt.md'),
    path.join(PROJECT_RALPH_DIR, 'config', 'plan-cleanup-prompt.md')
  );

  // Role files
  copyDir(
    path.join(templatesDir, 'roles'),
    path.join(PROJECT_RALPH_DIR, 'roles')
  );

  // Create empty progress file
  fs.writeFileSync(path.join(PROJECT_RALPH_DIR, 'tasks', 'progress.txt'), '');

  console.log(chalk.green('  ✓') + ' Templates copied');

  // Done
  console.log('[3/3] Done!');
  console.log('');
  console.log(chalk.green('Ralph initialized successfully!'));
  console.log('');
  console.log('Next steps:');
  console.log('  1. Plan a feature: @.ralph/roles/ralph-plan-feature.md in Claude Code');
  console.log('  2. Edit .ralph/tasks/testing-harness.md for your build/test commands');
  console.log('  3. Run \'ralph start\' to begin');
  console.log('');
}

// Custom help display
function showHelp() {
  console.log('');
  console.log(title('Ralph - AI Task Automation CLI'));
  console.log('');
  console.log(`Usage: ralph ${dim('{command} [options]')}`);
  console.log('');
  console.log('Commands:');
  console.log(`  ${cmd('init')}`);
  console.log('      Initialize Ralph in current directory (creates .ralph/)');
  console.log('');
  console.log(`  ${cmd('start')} ${dim('[--max N] [--model MODEL] [--local]')}`);
  console.log('      Open Docker sandbox and start loop inside container');
  console.log('');
  console.log(`  ${cmd('sandbox')}`);
  console.log('      Open interactive Docker shell');
  console.log('');
  console.log(`  ${cmd('loop')} ${dim('[--max N] [--model MODEL] [--local]')}`);
  console.log('      Start Ralph loop directly (default: 6 iterations, sonnet-4-5)');
  console.log('');
  console.log(`  ${cmd('plan')} ${dim('[--max N] [--model MODEL]')}`);
  console.log('      Plan features from vision.md (default: 10 iterations, cleanup every 5)');
  console.log('');
  console.log(`  ${cmd('burn')} ${dim('[--plan-max N] [--start-max N] [--model MODEL] [--local] [--sandbox]')}`);
  console.log('      Auto mode: plan from vision.md then execute (plan → execute)');
  console.log('');
  console.log(`  ${cmd('status')}`);
  console.log('      Check current PRD task status');
  console.log('');
  console.log(`  ${cmd('clear')}`);
  console.log('      Clear all log files (keeps progress)');
  console.log('');
  console.log(`  ${cmd('review')}`);
  console.log('      Review latest PR, merge to main');
  console.log('');
  console.log(`  ${cmd('cleanup')} ${dim('[feature]')}`);
  console.log('      Archive completed features');
  console.log('');
  console.log(`  ${cmd('help')}`);
  console.log('      Show this help message');
  console.log('');
  console.log('Options:');
  console.log(`  ${cmd('--max N')}          Maximum iterations (default: 6)`);
  console.log(`  ${cmd('--model MODEL')}    AI model: sonnet, opus, haiku (default: sonnet)`);
  console.log(`  ${cmd('--local')}           Commit locally, skip branch/push/PR creation`);
  console.log('');
  console.log('Examples:');
  console.log(`  ralph ${cmd('init')}                          # Set up Ralph in your project`);
  console.log(`  ralph ${cmd('start')} --max 5 --model haiku   # Run in Docker with haiku`);
  console.log(`  ralph ${cmd('loop')}                           # Run loop directly`);
  console.log(`  ralph ${cmd('loop')} --max 10 --model opus    # 10 iterations with opus`);
  console.log(`  ralph ${cmd('plan')}                           # Plan features from vision`);
  console.log(`  ralph ${cmd('plan')} --max 20 --model opus    # Deep planning with opus`);
  console.log(`  ralph ${cmd('burn')}                           # Plan + execute in one shot`);
  console.log(`  ralph ${cmd('burn')} --plan-max 20 --start-max 10  # Custom iteration limits`);
  console.log(`  ralph ${cmd('status')}                         # Check task progress`);
  console.log('');
}

// Setup CLI — disable commander's built-in help entirely
program
  .name('ralph')
  .version('1.0.0')
  .helpOption(false)
  .addHelpCommand(false)
  .configureOutput({
    outputError: () => {},  // suppress commander error output
  });

program
  .command('init')
  .description('Initialize Ralph in current directory')
  .action(doInit);

program
  .command('start')
  .option('--max <n>', 'Maximum iterations', '6')
  .option('--model <model>', 'AI model: sonnet, opus, haiku')
  .option('--local', 'Local mode: commit but skip branch/push/PR creation')
  .action((options) => {
    requireInit();
    if (options.local) process.env.RALPH_LOCAL = '1';
    console.log(chalk.dim('Starting Docker container...'));
    runScriptSync('start.sh', [options.max, options.model || '']);
  });

program
  .command('sandbox')
  .action(() => {
    requireInit();
    console.log(chalk.green('Opening Docker sandbox...'));
    runScriptSync('sandbox.sh');
  });

program
  .command('loop')
  .option('--max <n>', 'Maximum iterations', '6')
  .option('--model <model>', 'AI model: sonnet, opus, haiku')
  .option('--local', 'Local mode: commit but skip branch/push/PR creation')
  .action((options) => {
    requireInit();
    if (options.local) process.env.RALPH_LOCAL = '1';
    console.log(chalk.dim('Starting Ralph loop...'));
    const promptFile = path.join(PROJECT_RALPH_DIR, 'config', 'prompt.md');
    runScript('loop.sh', [promptFile, options.max, options.model || '']);
  });

program
  .command('plan')
  .option('--max <n>', 'Maximum iterations', '10')
  .option('--model <model>', 'AI model: sonnet, opus, haiku')
  .action((options) => {
    requireInit();
    const visionFile = path.join(PROJECT_RALPH_DIR, 'config', 'vision.md');
    if (!fs.existsSync(visionFile)) {
      console.error(chalk.red('Error: Vision file not found at .ralph/config/vision.md'));
      console.log('');
      console.log('Create your vision first:');
      console.log('  Use @.ralph/roles/ralph-plan-vision.md in Claude Code');
      process.exit(1);
    }
    console.log(chalk.dim('Starting Ralph planning loop...'));
    runScript('plan-loop.sh', [options.max, options.model || '']);
  });

program
  .command('burn')
  .option('--plan-max <n>', 'Max planning iterations', '10')
  .option('--start-max <n>', 'Max execution iterations', '6')
  .option('--model <model>', 'AI model: sonnet, opus, haiku')
  .option('--local', 'Local mode: commit but skip branch/push/PR creation')
  .option('--sandbox', 'Run both plan and execution phases inside Docker sandbox')
  .action((options) => {
    requireInit();
    const visionFile = path.join(PROJECT_RALPH_DIR, 'config', 'vision.md');
    if (!fs.existsSync(visionFile)) {
      console.error(chalk.red('Error: Vision file not found at .ralph/config/vision.md'));
      console.log('');
      console.log('Create your vision first:');
      console.log('  Use @.ralph/roles/ralph-plan-vision.md in Claude Code');
      process.exit(1);
    }
    if (options.local) process.env.RALPH_LOCAL = '1';
    console.log(chalk.dim('Starting Ralph auto mode (plan → execute)...'));
    runScript('auto.sh', [options.planMax, options.startMax, options.model || '', options.local ? '1' : '', options.sandbox ? '1' : '']);
  });

program
  .command('status')
  .action(() => {
    requireInit();
    runScript('status.sh');
  });

program
  .command('clear')
  .action(() => {
    requireInit();
    runScript('clear.sh');
  });

program
  .command('review')
  .action(() => {
    requireInit();
    runScript('review.sh');
  });

program
  .command('cleanup [feature]')
  .action((feature) => {
    requireInit();
    runScript('cleanup.sh', feature ? [feature] : []);
  });

program
  .command('help')
  .action(() => showHelp());

// Intercept before commander parses: handle no args, help, and --help
const args = process.argv.slice(2);
const firstArg = args[0];

if (!firstArg || firstArg === 'help' || firstArg === '--help' || firstArg === '-h') {
  showHelp();
  process.exit(0);
}

// Unknown commands → show help
program.on('command:*', () => {
  console.error(chalk.red(`Error: Unknown command '${args[0]}'`));
  showHelp();
  process.exit(1);
});

program.parse();
