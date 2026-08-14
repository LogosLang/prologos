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

let client: LanguageClient | undefined;
let replManager: ReplManager | undefined;
let decorationsManager: DecorationsManager | undefined;
let infoViewProvider: InfoViewProvider | undefined;
let propagatorViewManager: PropagatorViewManager | undefined;

export function activate(context: vscode.ExtensionContext) {
  const outputChannel = vscode.window.createOutputChannel('Prologos');
  const replChannel = vscode.window.createOutputChannel('Prologos REPL');
  outputChannel.appendLine('Prologos extension activating...');

  // Resolve Racket path — check setting, then common locations
  const config = vscode.workspace.getConfiguration('prologos');
  const configuredRacket = config.get<string>('racketPath');
  const racketPath = (configuredRacket && configuredRacket.length > 0)
    ? configuredRacket
    : findRacket();

  if (!racketPath) {
    vscode.window.showWarningMessage(
      'Prologos: Racket not found. Set prologos.racketPath in settings for LSP features.'
    );
    outputChannel.appendLine('ERROR: Racket executable not found. Checked:');
    outputChannel.appendLine('  /Applications/Racket v9.0/bin/racket');
    outputChannel.appendLine('  /Applications/Racket/bin/racket');
    outputChannel.appendLine('  /usr/local/bin/racket');
    outputChannel.appendLine('  /opt/homebrew/bin/racket');
    outputChannel.appendLine('  /usr/bin/racket');
    outputChannel.appendLine('Set prologos.racketPath in settings.');
    // Extension still provides syntax highlighting without LSP
    return;
  }

  outputChannel.appendLine(`Racket found: ${racketPath}`);

  // Path to the LSP server Racket file
  const serverModule = resolveServerPath(context);
  outputChannel.appendLine(`Server module: ${serverModule}`);

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
 * Find Racket executable on common macOS/Linux paths.
 */
function findRacket(): string | undefined {
  const candidates = [
    '/Applications/Racket v9.0/bin/racket',
    '/Applications/Racket/bin/racket',
    '/usr/local/bin/racket',
    '/opt/homebrew/bin/racket',
    '/usr/bin/racket',
  ];

  const fs = require('fs');
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return undefined;
}
