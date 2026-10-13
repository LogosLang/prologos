import * as vscode from 'vscode';
import * as path from 'path';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from 'vscode-languageclient/node';
import { ReplManager } from './repl';
import { DecorationsManager } from './decorations';
import { InfoViewProvider } from './infoview';
import { PropagatorViewManager } from './propagatorView';
import { PrologosSemanticTokens, LEGEND } from './semanticTokens';

let client: LanguageClient | undefined;
let replManager: ReplManager | undefined;
let decorationsManager: DecorationsManager | undefined;
let infoViewProvider: InfoViewProvider | undefined;
let propagatorViewManager: PropagatorViewManager | undefined;

export function activate(context: vscode.ExtensionContext) {
  const outputChannel = vscode.window.createOutputChannel('Prologos');
  const replChannel = vscode.window.createOutputChannel('Prologos REPL');
  outputChannel.appendLine('Prologos extension activating...');

  // Semantic highlighting is registered FIRST, deliberately.
  //
  // Everything below can `return` early — no Racket, no server.rkt — and those
  // returns would take highlighting with them. Highlighting depends on neither:
  // it runs the tree-sitter grammar in-process from a wasm asset shipped with
  // the extension. So it must not sit behind the LSP's preconditions.
  context.subscriptions.push(
    vscode.languages.registerDocumentSemanticTokensProvider(
      { scheme: 'file', language: 'prologos' },
      new PrologosSemanticTokens(context.extensionPath, outputChannel),
      LEGEND,
    ),
  );

  // Path to the LSP server Racket file. Resolved BEFORE Racket: the server's
  // compiled/ artifacts record which Racket version they need (see findRacket).
  const serverModule = resolveServerPath(context);
  outputChannel.appendLine(`Server module: ${serverModule}`);
  const compiledVersion = compiledRacketVersion(serverModule);
  if (compiledVersion) {
    outputChannel.appendLine(`Server compiled with Racket ${compiledVersion}`);
  }

  // Resolve Racket path — check setting, then installed Racket(s)
  const config = vscode.workspace.getConfiguration('prologos');
  const configuredRacket = config.get<string>('racketPath');
  const racketPath = (configuredRacket && configuredRacket.length > 0)
    ? configuredRacket
    : findRacket(compiledVersion);

  if (!racketPath) {
    vscode.window.showWarningMessage(
      'Prologos: Racket not found. Set prologos.racketPath in settings for LSP features.'
    );
    outputChannel.appendLine('ERROR: Racket executable not found. Checked:');
    for (const candidate of racketCandidates()) {
      outputChannel.appendLine(`  ${candidate}`);
    }
    outputChannel.appendLine('Set prologos.racketPath in settings.');
    // Extension still provides syntax highlighting without LSP
    return;
  }

  const runningVersion = racketVersion(racketPath);
  outputChannel.appendLine(`Racket found: ${racketPath} (v${runningVersion ?? '?'})`);

  // A runtime/bytecode version skew makes server.rkt exit at load time, which
  // the client only reports as "connection to server is erroring: write EPIPE".
  // Name the real cause up front instead.
  if (compiledVersion && runningVersion && compiledVersion !== runningVersion) {
    const msg =
      `Prologos: server.rkt was compiled with Racket ${compiledVersion} but will run ` +
      `on Racket ${runningVersion} (${racketPath}); it will fail to load. ` +
      `Point prologos.racketPath at Racket ${compiledVersion}, or recompile with ` +
      `\`raco make lsp/server.rkt\` using Racket ${runningVersion}.`;
    outputChannel.appendLine(`WARNING: ${msg}`);
    vscode.window.showWarningMessage(msg);
  }

  // Verify server file exists
  const fs = require('fs');
  if (!fs.existsSync(serverModule)) {
    vscode.window.showWarningMessage(
      `Prologos: LSP server not found at ${serverModule}. Set prologos.serverPath in settings.`
    );
    outputChannel.appendLine(`ERROR: Server file not found: ${serverModule}`);
    return;
  }

  outputChannel.appendLine(`Extension path: ${context.extensionPath}`);

  // Derived from the server path we just verified — NOT from extensionPath,
  // which points outside the checkout for a symlinked or .vsix install.
  const sourceRoot = resolveSourceRoot(serverModule);
  outputChannel.appendLine(`Source root: ${sourceRoot}`);

  const serverOptions: ServerOptions = {
    command: racketPath,
    args: [serverModule],
    options: {
      env: { ...process.env },
      // Set cwd to the prologos source root so requires resolve
      cwd: sourceRoot,
    },
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'prologos' }],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/*.prologos'),
    },
    outputChannel: outputChannel,
  };

  client = new LanguageClient(
    'prologos',
    'Prologos Language Server',
    serverOptions,
    clientOptions
  );

  // Initialize REPL infrastructure
  decorationsManager = new DecorationsManager();
  context.subscriptions.push(decorationsManager);

  client.start().then(
    () => {
      outputChannel.appendLine('LSP client started successfully');

      // REPL commands require a running client
      replManager = new ReplManager(client!, replChannel, decorationsManager!);

      // InfoView panel — sidebar with cursor-tracking type context
      infoViewProvider = new InfoViewProvider(client!);
      context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(
          InfoViewProvider.viewType,
          infoViewProvider
        )
      );
      context.subscriptions.push(infoViewProvider);

      // Register REPL commands
      context.subscriptions.push(
        vscode.commands.registerCommand('prologos.evalTopLevel', () =>
          replManager!.evalTopLevel()
        ),
        vscode.commands.registerCommand('prologos.evalSelection', () =>
          replManager!.evalSelection()
        ),
        vscode.commands.registerCommand('prologos.loadFile', () =>
          replManager!.loadFile()
        ),
        vscode.commands.registerCommand('prologos.typeOf', () =>
          replManager!.typeOf()
        ),
        vscode.commands.registerCommand('prologos.resetSession', () =>
          replManager!.resetSession()
        ),
        vscode.commands.registerCommand('prologos.toggleInfoView', () => {
          vscode.commands.executeCommand('prologos.infoView.focus');
        }),
        vscode.commands.registerCommand('prologos.showPropagatorView', () => {
          if (!propagatorViewManager) {
            propagatorViewManager = new PropagatorViewManager(client!, context.extensionPath);
          }
          propagatorViewManager.show();
        }),
        vscode.commands.registerCommand('prologos.showObservatory', () => {
          if (!propagatorViewManager) {
            propagatorViewManager = new PropagatorViewManager(client!, context.extensionPath);
          }
          propagatorViewManager.showObservatory();
        }),
      );

      // Auto-refresh Observatory panel on .prologos file save
      context.subscriptions.push(
        vscode.workspace.onDidSaveTextDocument((doc) => {
          if (doc.languageId === 'prologos' && propagatorViewManager) {
            propagatorViewManager.refreshIfOpen();
          }
        })
      );
    },
    (err) => {
      outputChannel.appendLine(`ERROR starting LSP client: ${err}`);
      vscode.window.showErrorMessage(`Prologos LSP failed to start: ${err.message || err}`);
    }
  );
}

export async function deactivate(): Promise<void> {
  if (client) {
    await client.stop();
  }
}

/** Relative location of the LSP server from the repo root. */
const SERVER_REL = path.join('racket', 'prologos', 'lsp', 'server.rkt');

/**
 * Find the LSP server.rkt file.
 *
 * The extension can be loaded several ways, and each puts `extensionPath`
 * somewhere different — so we resolve rather than assume:
 *
 *   1. `prologos.serverPath` setting — always wins.
 *   2. In place inside the repo (`code --extensionDevelopmentPath=...`):
 *      extensionPath IS <repo>/editors/vscode-prologos, so `../..` is the root.
 *   3. Symlinked into ~/.vscode/extensions: extensionPath is the SYMLINK, whose
 *      `../..` is ~/, not the repo. realpath() lands back in the repo.
 *   4. Copied/installed from a .vsix: no path relation to the repo at all —
 *      fall back to an open workspace folder that contains the server.
 *
 * Returns the case-2 guess when nothing is found, so the caller's
 * "not found at X" message names the path a developer expects.
 */
function resolveServerPath(context: vscode.ExtensionContext): string {
  const fs = require('fs');
  const config = vscode.workspace.getConfiguration('prologos');
  const configuredPath = config.get<string>('serverPath');
  if (configuredPath && configuredPath.length > 0) {
    return configuredPath;
  }

  const inRepo = path.join(context.extensionPath, '..', '..', SERVER_REL);

  const candidates = [inRepo];

  // Symlinked install — resolve the link back to the checkout.
  try {
    const real = fs.realpathSync(context.extensionPath);
    if (real !== context.extensionPath) {
      candidates.push(path.join(real, '..', '..', SERVER_REL));
    }
  } catch {
    // realpath can fail on a dangling link; the other candidates still apply.
  }

  // Installed copy — look for the checkout among the open workspace folders.
  for (const folder of vscode.workspace.workspaceFolders ?? []) {
    candidates.push(path.join(folder.uri.fsPath, SERVER_REL));
  }

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return path.resolve(candidate);
    }
  }

  return path.resolve(inRepo);
}

/**
 * The Racket source root (`<repo>/racket/prologos`), derived from the RESOLVED
 * server path rather than from extensionPath — the server is what actually
 * pins the checkout, and it is the one path we have already verified exists.
 */
function resolveSourceRoot(serverModule: string): string {
  // <root>/racket/prologos/lsp/server.rkt -> <root>/racket/prologos
  return path.resolve(path.dirname(serverModule), '..');
}

/**
 * The Racket version the LSP server's bytecode was compiled with, read from
 * `lsp/compiled/server_rkt.dep` (whose first datum is the version string,
 * e.g. `("9.3" tarm64osx ...)`). Undefined if not compiled yet.
 */
function compiledRacketVersion(serverModule: string): string | undefined {
  const fs = require('fs');
  const dep = path.join(path.dirname(serverModule), 'compiled', 'server_rkt.dep');
  try {
    const m = /^\(\s*"([^"]+)"/.exec(fs.readFileSync(dep, 'utf8'));
    return m ? m[1] : undefined;
  } catch {
    return undefined;
  }
}

/**
 * The version of a Racket executable: from its install dir name
 * (`/Applications/Racket v9.3/...`) when it has one, else by asking it.
 */
function racketVersion(exe: string): string | undefined {
  const fromDir = /Racket v(\d+(?:\.\d+)*)/.exec(exe);
  if (fromDir) {
    return fromDir[1];
  }
  try {
    const { spawnSync } = require('child_process');
    // `--version` prints the banner without loading racket/base — cheap.
    const out = spawnSync(exe, ['--version'], { encoding: 'utf8', timeout: 5000 });
    const m = /Racket v(\d+(?:\.\d+)*)/.exec(out.stdout ?? '');
    return m ? m[1] : undefined;
  } catch {
    return undefined;
  }
}

function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) {
      return d;
    }
  }
  return 0;
}

/**
 * Candidate Racket executables: every `/Applications/Racket v*` install
 * (several versions may coexist, e.g. for A/B benchmarking), then the usual
 * unversioned locations.
 */
function racketCandidates(): string[] {
  const fs = require('fs');
  const versioned: string[] = [];
  try {
    for (const entry of fs.readdirSync('/Applications') as string[]) {
      if (/^Racket v\d+(\.\d+)*$/.test(entry)) {
        versioned.push(path.join('/Applications', entry, 'bin', 'racket'));
      }
    }
  } catch {
    // No /Applications (Linux) — the unversioned paths below still apply.
  }
  return [
    ...versioned,
    '/Applications/Racket/bin/racket',
    '/usr/local/bin/racket',
    '/opt/homebrew/bin/racket',
    '/usr/bin/racket',
  ];
}

/**
 * Find a Racket executable for the LSP server.
 *
 * Racket refuses to load bytecode compiled by a different version ("loading
 * code: version mismatch"), so the right Racket is not "the first one on disk"
 * but the one matching `wantVersion` — the version server.rkt was compiled
 * with. With no match (or no compiled server), take the newest installed.
 */
function findRacket(wantVersion?: string): string | undefined {
  const fs = require('fs');
  const found = racketCandidates()
    .filter((p) => fs.existsSync(p))
    .map((p) => ({ path: p, version: racketVersion(p) }));

  if (wantVersion) {
    const match = found.find((c) => c.version === wantVersion);
    if (match) {
      return match.path;
    }
  }

  const newest = found
    .filter((c) => c.version !== undefined)
    .sort((a, b) => compareVersions(b.version!, a.version!))[0];
  return newest?.path ?? found[0]?.path;
}
