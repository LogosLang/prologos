import * as vscode from 'vscode';
import * as path from 'path';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext) {
  const outputChannel = vscode.window.createOutputChannel('Prologos');
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

  client.start().then(
    () => outputChannel.appendLine('LSP client started successfully'),
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
 * Checks relative to the extension, then falls back to common project locations.
 */
function resolveServerPath(context: vscode.ExtensionContext): string {
  // The server.rkt lives in the prologos source tree
  // When installed as extension: bundled alongside
  // During development: relative to workspace
  const candidates = [
    // Relative to extension
    path.join(context.extensionPath, '..', '..', 'racket', 'prologos', 'lsp', 'server.rkt'),
    // Development: workspace folder
    ...(vscode.workspace.workspaceFolders || []).map(f =>
      path.join(f.uri.fsPath, 'racket', 'prologos', 'lsp', 'server.rkt')
    ),
  ];

  // For now, use a setting or the first candidate
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
