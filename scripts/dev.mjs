import { spawn } from 'node:child_process';

const procs = [
  spawn(process.execPath, ['server/index.ts'], { stdio: 'inherit', env: process.env }),
  spawn('npx', ['vite', '--config', 'web/vite.config.ts'], { stdio: 'inherit', env: process.env, shell: process.platform === 'win32' }),
];

const stop = () => {
  for (const p of procs) p.kill('SIGTERM');
  process.exit(0);
};
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
for (const p of procs) p.on('exit', (code) => code && code !== 0 && console.error(`process exited with ${code}`));
