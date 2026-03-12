import * as vscode from 'vscode';
import { LanguageClient } from 'vscode-languageclient/node';

/**
 * Propagator Network Visualization panel.
 *
 * Phase 4a: Webview panel that requests $/prologos/propagatorSnapshot from
 * the LSP server and renders the network as an interactive graph.
 *
 * Current scope: panel skeleton + data request + HTML summary.
 * D3+d3-dag rendering will be added in Phase 4b.
 */

interface CellJson {
  id: number;
  value: string;
}

interface PropagatorJson {
  id: number;
  inputs: number[];
  outputs: number[];
}

interface NetworkJson {
  cells: CellJson[];
  propagators: PropagatorJson[];
  stats: {
    totalCells: number;
    totalPropagators: number;
    contradiction: number | null;
  };
}

interface CellDiffJson {
  cellId: number;
  oldValue: string;
  newValue: string;
  sourcePropagator: number;
}

interface BspRoundJson {
  roundNumber: number;
  cellDiffs: CellDiffJson[];
  propagatorsFired: number[];
  contradiction: number | null;
  atmsEvents: any[];
}

interface PropTraceJson {
  initialNetwork: NetworkJson;
  rounds: BspRoundJson[];
  finalNetwork: NetworkJson;
  metadata: Record<string, any>;
  error?: string;
}

export class PropagatorViewManager {
  private panel: vscode.WebviewPanel | undefined;
  private client: LanguageClient;

  constructor(client: LanguageClient) {
    this.client = client;
  }

  public async show() {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') {
      vscode.window.showInformationMessage('Open a .prologos file first');
      return;
    }

    const uri = editor.document.uri.toString();

    // Create or reveal the panel
    if (this.panel) {
      this.panel.reveal(vscode.ViewColumn.Beside);
    } else {
      this.panel = vscode.window.createWebviewPanel(
        'prologos.propagatorView',
        'Propagator Network',
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          retainContextWhenHidden: true,
        }
      );
      this.panel.onDidDispose(() => {
        this.panel = undefined;
      });
    }

    // Request snapshot from LSP server
    this.panel.webview.html = this.renderLoading();

    try {
      const response = await this.client.sendRequest(
        '$/prologos/propagatorSnapshot',
        { uri }
      ) as PropTraceJson;

      if (response.error) {
        this.panel.webview.html = this.renderError(response.error);
      } else {
        this.panel.webview.html = this.renderSnapshot(response);
      }
    } catch (err: any) {
      this.panel.webview.html = this.renderError(err.message || String(err));
    }
  }

  private renderLoading(): string {
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: var(--vscode-font-family, sans-serif);
      color: var(--vscode-foreground, #ccc);
      background: var(--vscode-editor-background, #1e1e1e);
      padding: 20px;
    }
  </style>
</head>
<body>
  <p>Loading propagator network...</p>
</body>
</html>`;
  }

  private renderError(message: string): string {
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: var(--vscode-font-family, sans-serif);
      color: var(--vscode-foreground, #ccc);
      background: var(--vscode-editor-background, #1e1e1e);
      padding: 20px;
    }
    .error { color: var(--vscode-errorForeground, #f44); }
  </style>
</head>
<body>
  <p class="error">No propagator trace available.</p>
  <p style="opacity: 0.7; font-size: 0.9em;">
    Save the file to trigger elaboration, then try again.
  </p>
  <p style="opacity: 0.5; font-size: 0.8em;">${escapeHtml(message)}</p>
</body>
</html>`;
  }

  private renderSnapshot(trace: PropTraceJson): string {
    const net = trace.finalNetwork;
    const stats = net.stats;
    const rounds = trace.rounds;

    // Build adjacency info for the table
    const cellRows = net.cells.map(c => {
      const val = c.value.length > 40 ? c.value.substring(0, 40) + '...' : c.value;
      return `<tr><td>#${c.id}</td><td><code>${escapeHtml(val)}</code></td></tr>`;
    }).join('\n');

    const propRows = net.propagators.map(p => {
      const ins = p.inputs.map(i => `#${i}`).join(', ');
      const outs = p.outputs.map(o => `#${o}`).join(', ');
      return `<tr><td>P${p.id}</td><td>${ins}</td><td>${outs}</td></tr>`;
    }).join('\n');

    const roundRows = rounds.map(r => {
      const diffs = r.cellDiffs.length;
      const fired = r.propagatorsFired.length;
      const contra = r.contradiction !== null ? ` <span class="contra">CONTRA #${r.contradiction}</span>` : '';
      return `<tr>
        <td>${r.roundNumber}</td>
        <td>${fired}</td>
        <td>${diffs}</td>
        <td>${contra || '-'}</td>
      </tr>`;
    }).join('\n');

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: var(--vscode-font-family, sans-serif);
      color: var(--vscode-foreground, #ccc);
      background: var(--vscode-editor-background, #1e1e1e);
      padding: 16px;
      font-size: 13px;
    }
    h2 { margin: 0 0 8px 0; font-size: 1.1em; }
    h3 { margin: 16px 0 6px 0; font-size: 0.95em; opacity: 0.8; }
    .stats { display: flex; gap: 16px; margin-bottom: 16px; }
    .stat {
      padding: 8px 12px;
      background: var(--vscode-textBlockQuote-background, #252526);
      border-radius: 4px;
    }
    .stat-value { font-size: 1.4em; font-weight: bold; }
    .stat-label { font-size: 0.8em; opacity: 0.7; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 16px; }
    th, td {
      padding: 4px 8px;
      text-align: left;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
    }
    th { opacity: 0.7; font-size: 0.85em; }
    code { font-family: var(--vscode-editor-font-family, monospace); font-size: 0.9em; }
    .contra { color: var(--vscode-errorForeground, #f44); font-weight: bold; }
    details { margin-bottom: 8px; }
    summary { cursor: pointer; opacity: 0.8; }
    summary:hover { opacity: 1; }
    .placeholder {
      margin-top: 24px;
      padding: 16px;
      background: var(--vscode-textBlockQuote-background, #252526);
      border-radius: 4px;
      text-align: center;
      opacity: 0.6;
    }
  </style>
</head>
<body>
  <h2>Propagator Network</h2>

  <div class="stats">
    <div class="stat">
      <div class="stat-value">${stats.totalCells}</div>
      <div class="stat-label">Cells</div>
    </div>
    <div class="stat">
      <div class="stat-value">${stats.totalPropagators}</div>
      <div class="stat-label">Propagators</div>
    </div>
    <div class="stat">
      <div class="stat-value">${rounds.length}</div>
      <div class="stat-label">BSP Rounds</div>
    </div>
    ${stats.contradiction !== null
      ? `<div class="stat"><div class="stat-value contra">!</div><div class="stat-label">Contradiction</div></div>`
      : ''}
  </div>

  ${rounds.length > 0 ? `
  <details open>
    <summary><strong>BSP Rounds</strong></summary>
    <table>
      <tr><th>Round</th><th>Fired</th><th>Diffs</th><th>Status</th></tr>
      ${roundRows}
    </table>
  </details>` : ''}

  <details>
    <summary><strong>Cells (${net.cells.length})</strong></summary>
    <table>
      <tr><th>ID</th><th>Value</th></tr>
      ${cellRows}
    </table>
  </details>

  <details>
    <summary><strong>Propagators (${net.propagators.length})</strong></summary>
    <table>
      <tr><th>ID</th><th>Inputs</th><th>Outputs</th></tr>
      ${propRows}
    </table>
  </details>

  <div class="placeholder">
    Graph visualization (D3 + d3-dag) will be added in Phase 4b.
  </div>
</body>
</html>`;
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
