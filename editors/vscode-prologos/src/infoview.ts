import * as vscode from 'vscode';
import { LanguageClient } from 'vscode-languageclient/node';

/**
 * Prologos InfoView panel — Lean 4–style sidebar showing type context,
 * file outline, diagnostics, and REPL state. Updates on cursor movement.
 */

interface CursorContextResponse {
  typeAtCursor: string | null;
  symbolKind: string | null;
  fileContext: {
    namespace: string | null;
    definitions: Array<{ name: string; type: string; line: number; kind: string }>;
    imports: string[];
  };
  diagnostics: Array<{ message: string; line: number; severity: string }>;
  replState: {
    active: boolean;
    evalCount: number;
    lastResult: string | null;
  };
}

export class InfoViewProvider implements vscode.WebviewViewProvider {
  public static readonly viewType = 'prologos.infoView';

  private view?: vscode.WebviewView;
  private client: LanguageClient;
  private debounceTimer?: ReturnType<typeof setTimeout>;
  private sticky = false;
  private stickyUri?: string;
  private stickyLine?: number;
  private stickyChar?: number;
  private lastResponse?: CursorContextResponse;
  private disposables: vscode.Disposable[] = [];

  constructor(client: LanguageClient) {
    this.client = client;

    // Listen for cursor changes (debounced)
    this.disposables.push(
      vscode.window.onDidChangeTextEditorSelection((e) => {
        if (this.sticky) return;
        if (e.textEditor.document.languageId !== 'prologos') return;
        this.debouncedUpdate(e.textEditor);
      })
    );

    // Listen for active editor changes
    this.disposables.push(
      vscode.window.onDidChangeActiveTextEditor((editor) => {
        if (this.sticky) return;
        if (editor && editor.document.languageId === 'prologos') {
          this.debouncedUpdate(editor);
        }
      })
    );
  }

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken
  ): void {
    this.view = webviewView;

    webviewView.webview.options = {
      enableScripts: true,
    };

    // Handle messages from the webview
    webviewView.webview.onDidReceiveMessage((message) => {
      switch (message.command) {
        case 'navigateTo':
          {
            const activeUri = vscode.window.activeTextEditor?.document.uri.toString() || message.uri;
            this.navigateToLine(activeUri, message.line);
          }
          break;
        case 'toggleSticky':
          this.toggleSticky();
          break;
        case 'copyType':
          if (message.text) {
            vscode.env.clipboard.writeText(message.text);
            vscode.window.showInformationMessage('Type copied to clipboard');
          }
          break;
        case 'refresh':
          this.sticky = false;
          const editor = vscode.window.activeTextEditor;
          if (editor && editor.document.languageId === 'prologos') {
            this.updateContext(editor);
          }
          break;
      }
    });

    // Initial render
    webviewView.webview.html = this.getHtml(undefined);

    // Query immediately if there's an active prologos editor
    const editor = vscode.window.activeTextEditor;
    if (editor && editor.document.languageId === 'prologos') {
      this.updateContext(editor);
    }
  }

  private debouncedUpdate(editor: vscode.TextEditor) {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }
    this.debounceTimer = setTimeout(() => this.updateContext(editor), 100);
  }

  private async updateContext(editor: vscode.TextEditor) {
    if (!this.view) return;

    const position = editor.selection.active;
    const uri = editor.document.uri.toString();

    try {
      const response = await this.client.sendRequest<CursorContextResponse>(
        '$/prologos/cursorContext',
        {
          uri,
          line: position.line,
          character: position.character,
        }
      );

      this.lastResponse = response;
      this.view.webview.html = this.getHtml(response);
    } catch (err) {
      // Server might not support this method yet — show placeholder
      this.view.webview.html = this.getHtml(undefined);
    }
  }

  private navigateToLine(uri: string, line: number) {
    const parsedUri = vscode.Uri.parse(uri);
    vscode.workspace.openTextDocument(parsedUri).then((doc) => {
      vscode.window.showTextDocument(doc, { preview: false }).then((editor) => {
        const pos = new vscode.Position(line, 0);
        editor.selection = new vscode.Selection(pos, pos);
        editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
      });
    });
  }

  toggleSticky() {
    this.sticky = !this.sticky;
    if (this.sticky) {
      const editor = vscode.window.activeTextEditor;
      if (editor) {
        this.stickyUri = editor.document.uri.toString();
        this.stickyLine = editor.selection.active.line;
        this.stickyChar = editor.selection.active.character;
      }
    }
    // Re-render to update sticky indicator
    if (this.view) {
      this.view.webview.html = this.getHtml(this.lastResponse);
    }
  }

  dispose() {
    for (const d of this.disposables) {
      d.dispose();
    }
  }

  // ============================================================
  // HTML rendering
  // ============================================================

  private getHtml(data: CursorContextResponse | undefined): string {
    const stickyClass = this.sticky ? 'sticky-active' : '';

    // Type at cursor section
    let typeSection: string;
    if (data?.typeAtCursor) {
      typeSection = `
        <div class="section type-section">
          <div class="section-header">
            <span class="section-icon">τ</span>
            <span class="section-title">Type at Cursor</span>
            <button class="icon-btn" onclick="copyType()" title="Copy type">⎘</button>
          </div>
          <pre class="type-display" id="type-text">${escapeHtml(data.typeAtCursor)}</pre>
        </div>`;
    } else {
      typeSection = `
        <div class="section type-section">
          <div class="section-header">
            <span class="section-icon">τ</span>
            <span class="section-title">Type at Cursor</span>
          </div>
          <div class="placeholder">Move cursor to a symbol</div>
        </div>`;
    }

    // File outline section
    let outlineSection: string;
    if (data?.fileContext?.definitions && data.fileContext.definitions.length > 0) {
      const ns = data.fileContext.namespace
        ? `<div class="namespace">${escapeHtml(data.fileContext.namespace)}</div>`
        : '';
      const defs = data.fileContext.definitions
        .map(
          (d) =>
            `<div class="outline-item" onclick="navigateTo(${d.line})">
              <span class="outline-kind">${kindIcon(d.kind)}</span>
              <span class="outline-name">${escapeHtml(d.name)}</span>
              <span class="outline-type">${escapeHtml(d.type)}</span>
            </div>`
        )
        .join('\n');
      outlineSection = `
        <details class="section" open>
          <summary class="section-header">
            <span class="section-icon">◈</span>
            <span class="section-title">File Outline</span>
            <span class="badge">${data.fileContext.definitions.length}</span>
          </summary>
          ${ns}
          <div class="outline-list">${defs}</div>
        </details>`;
    } else {
      outlineSection = `
        <details class="section" open>
          <summary class="section-header">
            <span class="section-icon">◈</span>
            <span class="section-title">File Outline</span>
          </summary>
          <div class="placeholder">No definitions found</div>
        </details>`;
    }

    // Diagnostics section
    let diagSection: string;
    if (data?.diagnostics && data.diagnostics.length > 0) {
      const items = data.diagnostics
        .map(
          (d) =>
            `<div class="diag-item diag-${d.severity}" onclick="navigateTo(${d.line})">
              <span class="diag-icon">${d.severity === 'error' ? '✗' : '⚠'}</span>
              <span class="diag-line">L${d.line + 1}</span>
              <span class="diag-msg">${escapeHtml(d.message)}</span>
            </div>`
        )
        .join('\n');
      diagSection = `
        <details class="section" open>
          <summary class="section-header">
            <span class="section-icon">⊘</span>
            <span class="section-title">Diagnostics</span>
            <span class="badge badge-error">${data.diagnostics.length}</span>
          </summary>
          <div class="diag-list">${items}</div>
        </details>`;
    } else {
      diagSection = `
        <details class="section">
          <summary class="section-header">
            <span class="section-icon">✓</span>
            <span class="section-title">Diagnostics</span>
            <span class="badge badge-ok">0</span>
          </summary>
          <div class="placeholder">No diagnostics</div>
        </details>`;
    }

    // REPL section
    let replSection: string;
    if (data?.replState?.active) {
      const lastResult = data.replState.lastResult
        ? `<pre class="repl-result">${escapeHtml(data.replState.lastResult)}</pre>`
        : '<div class="placeholder">No results yet</div>';
      replSection = `
        <details class="section">
          <summary class="section-header">
            <span class="section-icon">λ</span>
            <span class="section-title">REPL</span>
            <span class="badge badge-active">active</span>
          </summary>
          <div class="repl-info">Evals: ${data.replState.evalCount}</div>
          ${lastResult}
        </details>`;
    } else {
      replSection = `
        <details class="section">
          <summary class="section-header">
            <span class="section-icon">λ</span>
            <span class="section-title">REPL</span>
          </summary>
          <div class="placeholder">No active session — press ⌘+Enter to evaluate</div>
        </details>`;
    }

    return `<!DOCTYPE html>
<html>
<head>
  <style>
    :root {
      --bg: var(--vscode-sideBar-background);
      --fg: var(--vscode-sideBar-foreground, var(--vscode-foreground));
      --border: var(--vscode-panel-border, var(--vscode-widget-border, #444));
      --accent: var(--vscode-focusBorder, #007acc);
      --hover-bg: var(--vscode-list-hoverBackground, rgba(255,255,255,0.04));
      --code-bg: var(--vscode-textCodeBlock-background, rgba(0,0,0,0.2));
      --error-fg: var(--vscode-errorForeground, #f44);
      --warn-fg: var(--vscode-editorWarning-foreground, #fa4);
      --success-fg: var(--vscode-terminal-ansiGreen, #4a4);
      --font-mono: var(--vscode-editor-font-family, 'Menlo', monospace);
      --font-size: var(--vscode-editor-font-size, 13px);
    }

    body {
      margin: 0;
      padding: 8px;
      background: var(--bg);
      color: var(--fg);
      font-family: var(--vscode-font-family, -apple-system, sans-serif);
      font-size: var(--font-size);
      line-height: 1.4;
    }

    .toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 4px 0 8px;
      border-bottom: 1px solid var(--border);
      margin-bottom: 8px;
    }

    .toolbar-title {
      font-weight: 600;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      opacity: 0.7;
    }

    .toolbar-actions {
      display: flex;
      gap: 4px;
    }

    .icon-btn {
      background: none;
      border: none;
      color: var(--fg);
      cursor: pointer;
      padding: 2px 4px;
      border-radius: 3px;
      font-size: 14px;
      opacity: 0.6;
    }
    .icon-btn:hover { opacity: 1; background: var(--hover-bg); }
    .icon-btn.active { color: var(--accent); opacity: 1; }

    .section {
      margin-bottom: 4px;
    }

    .section-header {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 4px 2px;
      cursor: pointer;
      user-select: none;
      font-size: 12px;
      font-weight: 500;
    }
    .section-header:hover { background: var(--hover-bg); border-radius: 3px; }

    .section-icon {
      font-size: 14px;
      width: 18px;
      text-align: center;
      opacity: 0.8;
    }

    .section-title { flex: 1; }

    .badge {
      font-size: 10px;
      padding: 1px 6px;
      border-radius: 8px;
      background: var(--code-bg);
      opacity: 0.8;
    }
    .badge-error { background: var(--error-fg); color: #fff; opacity: 1; }
    .badge-ok { background: var(--success-fg); color: #fff; opacity: 1; }
    .badge-active { background: var(--accent); color: #fff; opacity: 1; }

    .type-display {
      font-family: var(--font-mono);
      font-size: 12px;
      padding: 6px 8px;
      margin: 4px 0;
      background: var(--code-bg);
      border-radius: 4px;
      white-space: pre-wrap;
      word-break: break-word;
      border-left: 3px solid var(--accent);
    }

    .type-section .section-header {
      cursor: default;
    }

    .placeholder {
      padding: 8px 10px;
      opacity: 0.5;
      font-style: italic;
      font-size: 12px;
    }

    .namespace {
      padding: 2px 10px;
      font-size: 11px;
      opacity: 0.6;
      font-family: var(--font-mono);
    }

    .outline-list, .diag-list {
      padding: 2px 0;
    }

    .outline-item, .diag-item {
      display: flex;
      align-items: baseline;
      gap: 6px;
      padding: 2px 8px;
      cursor: pointer;
      border-radius: 3px;
      font-size: 12px;
    }
    .outline-item:hover, .diag-item:hover {
      background: var(--hover-bg);
    }

    .outline-kind {
      width: 16px;
      text-align: center;
      font-size: 11px;
      opacity: 0.7;
    }
    .outline-name {
      font-family: var(--font-mono);
      font-weight: 500;
    }
    .outline-type {
      font-family: var(--font-mono);
      opacity: 0.5;
      font-size: 11px;
      margin-left: auto;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 50%;
    }

    .diag-icon { width: 14px; text-align: center; }
    .diag-line {
      font-family: var(--font-mono);
      font-size: 10px;
      opacity: 0.6;
      min-width: 28px;
    }
    .diag-msg {
      flex: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .diag-error .diag-icon { color: var(--error-fg); }
    .diag-warning .diag-icon { color: var(--warn-fg); }

    .repl-info {
      padding: 2px 10px;
      font-size: 11px;
      opacity: 0.6;
    }
    .repl-result {
      font-family: var(--font-mono);
      font-size: var(--font-size);
      padding: 6px 10px;
      margin: 4px 0;
      background: var(--code-bg);
      border-radius: 4px;
      white-space: pre-wrap;
      word-break: break-word;
      max-height: 120px;
      overflow-y: auto;
    }

    .sticky-indicator {
      font-size: 10px;
      color: var(--accent);
      margin-left: 4px;
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <span class="toolbar-title">Prologos${this.sticky ? ' <span class="sticky-indicator">📌 pinned</span>' : ''}</span>
    <div class="toolbar-actions">
      <button class="icon-btn ${stickyClass}" onclick="toggleSticky()" title="Pin/unpin cursor position">📌</button>
      <button class="icon-btn" onclick="refresh()" title="Refresh">↻</button>
    </div>
  </div>

  ${typeSection}
  ${outlineSection}
  ${diagSection}
  ${replSection}

  <script>
    const vscode = acquireVsCodeApi();

    function navigateTo(line) {
      vscode.postMessage({ command: 'navigateTo', uri: '', line: line });
    }

    function toggleSticky() {
      vscode.postMessage({ command: 'toggleSticky' });
    }

    function copyType() {
      const el = document.getElementById('type-text');
      if (el) {
        vscode.postMessage({ command: 'copyType', text: el.textContent });
      }
    }

    function refresh() {
      vscode.postMessage({ command: 'refresh' });
    }
  </script>
</body>
</html>`;
  }
}

// ============================================================
// Helpers
// ============================================================

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function kindIcon(kind: string): string {
  switch (kind) {
    case 'function':
      return 'ƒ';
    case 'variable':
      return '𝑥';
    case 'type':
      return 'T';
    case 'trait':
      return '⊳';
    case 'data':
      return '▣';
    case 'module':
      return '◫';
    case 'spec':
      return '⊢';
    default:
      return '·';
  }
}
