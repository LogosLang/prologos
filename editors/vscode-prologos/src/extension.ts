import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
  console.log('Prologos extension activated');

  // Tier 1: Static features only (syntax highlighting via TextMate grammar,
  // language configuration, snippets). No LSP server yet.
  //
  // Tier 2 will add: LSP client connection to Racket server process
  // for diagnostics, go-to-definition, document symbols, signature help.
}

export function deactivate() {
  console.log('Prologos extension deactivated');
}
