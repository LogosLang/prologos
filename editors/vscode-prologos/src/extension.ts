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

  const serverOptions: ServerOptions = {
    command: racketPath,
    args: [serverModule],
    options: {
      env: { ...process.env },
      // Set cwd to the prologos source root so requires resolve
      cwd: path.join(context.extensionPath, '..', '..', 'racket', 'prologos'),
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

/**
 * Find the LSP server.rkt file.
 */
function resolveServerPath(context: vscode.ExtensionContext): string {
  const config = vscode.workspace.getConfiguration('prologos');
  const configuredPath = config.get<string>('serverPath');
  if (configuredPath) {
    return configuredPath;
  }
  // Default: assume extension is in editors/vscode-prologos/
  return path.join(context.extensionPath, '..', '..', 'racket', 'prologos', 'lsp', 'server.rkt');
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
