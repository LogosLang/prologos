import * as vscode from 'vscode';
import * as path from 'path';
import { LanguageClient } from 'vscode-languageclient/node';

/**
 * Propagator Network Visualization panel.
 *
 * Phase 4a: Webview panel skeleton + data request + HTML summary.
 * Phase 4b: Canvas rendering with d3-zoom, topological layered layout,
 *           bipartite DAG (cells = circles, propagators = diamonds).
 */

interface CellJson {
  id: number;
  value: string;
  subsystem?: string;  // "type-inference" | "infrastructure" | "multiplicity" | "unknown"
  source?: string;     // provenance string from elab-cell-info
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

// Observatory interfaces (multi-network capture)
interface ObservatoryCellJson extends CellJson {
  label?: string;
  domain?: string;
  cellSubsystem?: string;
  cellSourceLoc?: { line: number; col: number } | null;
}

interface ObservatoryCaptureJson {
  id: string;
  subsystem: string;
  label: string;
  status: string;
  statusDetail: string | null;
  parentId: string | null;
  sequenceNumber: number;
  timestampMs: number;
  network: NetworkJson;
  trace: PropTraceJson | null;
}

interface CrossNetLinkJson {
  fromCapture: string;
  fromCell: number;
  toCapture: string;
  toCell: number;
  relation: string;
}

interface ObservatoryMetadata {
  totalCaptures: number;
  subsystems: string[];
  file?: string;
  [key: string]: any;
}

interface ObservatoryJson {
  version: number;
  observatory: {
    captures: ObservatoryCaptureJson[];
    links: CrossNetLinkJson[];
    metadata: ObservatoryMetadata;
  };
  error?: string;
}

export class PropagatorViewManager {
  private panel: vscode.WebviewPanel | undefined;
  private client: LanguageClient;
  private extensionPath: string;
  private lastUri: string | undefined;         // Track last displayed URI for auto-refresh
  private lastSelectedIndex: number = 0;       // Preserve capture selection across refreshes
  private refreshDebounceTimer: NodeJS.Timeout | undefined;

  constructor(client: LanguageClient, extensionPath?: string) {
    this.client = client;
    this.extensionPath = extensionPath || '';
  }

  public setExtensionPath(p: string) {
    this.extensionPath = p;
  }

  public async show() {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') {
      vscode.window.showInformationMessage('Open a .prologos file first');
      return;
    }

    const uri = editor.document.uri.toString();
    this.lastUri = uri;

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
          localResourceRoots: [
            vscode.Uri.file(path.join(this.extensionPath, 'node_modules')),
          ],
        }
      );
      this.panel.onDidDispose(() => {
        this.panel = undefined;
      });
      this.setupPanelMessageHandler();
    }

    // Request snapshot from LSP server
    this.panel.webview.html = this.renderLoading();

    try {
      const response = await this.client.sendRequest(
        '$/prologos/propagatorSnapshot',
        { uri }
      ) as PropTraceJson;

      if (response.error) {
        // No old-style trace — fall back to observatory view
        await this.showObservatoryForUri(uri);
      } else {
        this.panel.webview.html = this.renderSnapshot(response);
      }
    } catch (err: any) {
      // Propagator trace request failed — try observatory fallback
      try {
        await this.showObservatoryForUri(uri);
      } catch {
        this.panel.webview.html = this.renderError(err.message || String(err));
      }
    }
  }

  /**
   * Show the Observatory view — multi-network visualization.
   * Requests $/prologos/observatorySnapshot and renders a network selector
   * with per-capture graph views and subsystem color coding.
   */
  /**
   * Auto-refresh: if the panel is open and visible, re-request observatory data
   * for the last URI and re-render. Debounced to avoid rapid re-requests on
   * multiple quick saves. Preserves the currently selected capture index.
   */
  public refreshIfOpen() {
    if (!this.panel || !this.panel.visible || !this.lastUri) {
      return;
    }

    // Debounce: clear any pending refresh and schedule a new one (300ms)
    if (this.refreshDebounceTimer) {
      clearTimeout(this.refreshDebounceTimer);
    }
    this.refreshDebounceTimer = setTimeout(async () => {
      this.refreshDebounceTimer = undefined;
      if (!this.panel || !this.lastUri) { return; }
      await this.showObservatoryForUri(this.lastUri);
    }, 300);
  }

  public async showObservatory() {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') {
      vscode.window.showInformationMessage('Open a .prologos file first');
      return;
    }

    const uri = editor.document.uri.toString();
    this.lastUri = uri;

    if (this.panel) {
      this.panel.reveal(vscode.ViewColumn.Beside);
    } else {
      this.panel = vscode.window.createWebviewPanel(
        'prologos.propagatorView',
        'Propagator Observatory',
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          retainContextWhenHidden: true,
          localResourceRoots: [
            vscode.Uri.file(path.join(this.extensionPath, 'node_modules')),
          ],
        }
      );
      this.panel.onDidDispose(() => {
        this.panel = undefined;
      });
      this.setupPanelMessageHandler();
    }

    this.panel.webview.html = this.renderLoading();
    await this.showObservatoryForUri(uri);
  }

  /**
   * Set up message handler for webview → extension host communication.
   * Handles source-location linking (cell click → editor jump).
   */
  private setupPanelMessageHandler() {
    if (!this.panel) { return; }
    this.panel.webview.onDidReceiveMessage(async (msg) => {
      if (msg.type === 'revealSourceLocation' && this.lastUri) {
        try {
          const uri = vscode.Uri.parse(this.lastUri);
          const doc = await vscode.workspace.openTextDocument(uri);
          const editor = await vscode.window.showTextDocument(doc, vscode.ViewColumn.One);
          const line = Math.max(0, (msg.line || 1) - 1); // Convert 1-based to 0-based
          const col = Math.max(0, (msg.col || 1) - 1);
          const pos = new vscode.Position(line, col);
          editor.selection = new vscode.Selection(pos, pos);
          editor.revealRange(
            new vscode.Range(pos, pos),
            vscode.TextEditorRevealType.InCenterIfOutsideViewport
          );
        } catch (err) {
          // Silently fail — source loc may be stale
        }
      }
    });
  }

  /**
   * Internal: request observatory snapshot for a URI and render it into the existing panel.
   * Used by both showObservatory() and as fallback from show() when no old-style trace is available.
   */
  private async showObservatoryForUri(uri: string) {
    if (!this.panel) { return; }
    try {
      const response = await this.client.sendRequest(
        '$/prologos/observatorySnapshot',
        { uri }
      ) as ObservatoryJson;

      if (response.error) {
        this.panel.webview.html = this.renderError(response.error);
      } else {
        this.panel.webview.html = this.renderObservatory(response);
      }
    } catch (err: any) {
      this.panel.webview.html = this.renderError(err.message || String(err));
    }
  }

  private getD3Uri(): vscode.Uri | undefined {
    if (!this.panel || !this.extensionPath) { return undefined; }
    const d3Path = path.join(this.extensionPath, 'node_modules', 'd3', 'dist', 'd3.min.js');
    return this.panel.webview.asWebviewUri(vscode.Uri.file(d3Path));
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
      word-break: break-word;
      overflow-wrap: break-word;
    }
    .error { color: var(--vscode-errorForeground, #f44); }
    .detail { font-family: var(--vscode-editor-font-family, monospace); font-size: 0.8em; opacity: 0.5; white-space: pre-wrap; word-break: break-all; }
  </style>
</head>
<body>
  <p class="error">No propagator trace available.</p>
  <p style="opacity: 0.7; font-size: 0.9em;">
    Save the file to trigger elaboration, then try again.
  </p>
  <p class="detail">${escapeHtml(message)}</p>
</body>
</html>`;
  }

  private renderSnapshot(trace: PropTraceJson): string {
    const d3Uri = this.getD3Uri();
    const net = trace.finalNetwork;
    const stats = net.stats;
    const rounds = trace.rounds;

    // Serialize trace data for the webview script
    const traceDataJson = JSON.stringify(trace).replace(/</g, '\\u003c');

    // Build the tabular fallback rows
    const cellRows = net.cells.map(c => {
      const val = c.value.length > 40 ? c.value.substring(0, 40) + '...' : c.value;
      const sub = c.subsystem || '';
      return `<tr><td>#${c.id}</td><td>${escapeHtml(sub)}</td><td><code>${escapeHtml(val)}</code></td></tr>`;
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
  ${d3Uri ? `<script src="${d3Uri}"></script>` : ''}
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: var(--vscode-font-family, sans-serif);
      color: var(--vscode-foreground, #ccc);
      background: var(--vscode-editor-background, #1e1e1e);
      padding: 0;
      margin: 0;
      overflow: hidden;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }
    .header {
      padding: 8px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0;
    }
    h2 { margin: 0; font-size: 1.1em; }
    .stats { display: flex; gap: 12px; }
    .stat {
      padding: 4px 8px;
      background: var(--vscode-textBlockQuote-background, #252526);
      border-radius: 4px;
      font-size: 0.85em;
    }
    .stat-value { font-weight: bold; margin-right: 4px; }
    .stat-label { opacity: 0.7; }
    .contra { color: var(--vscode-errorForeground, #f44); font-weight: bold; }

    /* Graph canvas area */
    .graph-container {
      flex: 1;
      position: relative;
      overflow: hidden;
    }
    canvas {
      display: block;
      width: 100%;
      height: 100%;
    }
    .tooltip {
      position: absolute;
      pointer-events: none;
      background: var(--vscode-editorHoverWidget-background, #252526);
      border: 1px solid var(--vscode-editorHoverWidget-border, #454545);
      color: var(--vscode-editorHoverWidget-foreground, #ccc);
      padding: 6px 10px;
      border-radius: 4px;
      font-size: 12px;
      font-family: var(--vscode-editor-font-family, monospace);
      max-width: 300px;
      white-space: pre-wrap;
      display: none;
      z-index: 10;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }

    /* Tabular fallback below canvas */
    .tables {
      max-height: 40vh;
      overflow-y: auto;
      padding: 8px 16px;
      border-top: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0;
    }
    h3 { margin: 8px 0 4px 0; font-size: 0.9em; opacity: 0.8; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 8px; }
    th, td {
      padding: 3px 6px;
      text-align: left;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
      font-size: 0.85em;
      word-break: break-word;
      overflow-wrap: break-word;
    }
    th { opacity: 0.7; font-size: 0.8em; }
    code { font-family: var(--vscode-editor-font-family, monospace); font-size: 0.9em; }
    details { margin-bottom: 4px; }
    summary { cursor: pointer; opacity: 0.8; font-size: 0.9em; }
    summary:hover { opacity: 1; }

    /* Legend */
    .legend {
      position: absolute;
      bottom: 8px;
      left: 8px;
      background: var(--vscode-textBlockQuote-background, #252526);
      border: 1px solid var(--vscode-widget-border, #333);
      border-radius: 4px;
      padding: 6px 10px;
      font-size: 11px;
      opacity: 0.85;
      z-index: 5;
    }
    .legend-item { display: flex; align-items: center; gap: 6px; margin: 2px 0; }
    .legend-swatch {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      display: inline-block;
    }
    .legend-diamond {
      width: 12px;
      height: 12px;
      display: inline-block;
      transform: rotate(45deg);
    }
  </style>
</head>
<body>
  <div class="header">
    <h2>Propagator Network</h2>
    <div class="stats">
      <div class="stat">
        <span class="stat-value">${stats.totalCells}</span>
        <span class="stat-label">Cells</span>
      </div>
      <div class="stat">
        <span class="stat-value">${stats.totalPropagators}</span>
        <span class="stat-label">Props</span>
      </div>
      <div class="stat">
        <span class="stat-value">${rounds.length}</span>
        <span class="stat-label">Rounds</span>
      </div>
      ${stats.contradiction !== null
        ? `<div class="stat"><span class="stat-value contra">!</span><span class="stat-label">Contradiction</span></div>`
        : ''}
    </div>
  </div>

  <div class="graph-container" id="graph-container">
    <canvas id="graph-canvas"></canvas>
    <div class="tooltip" id="tooltip"></div>
    <div class="legend">
      <div class="legend-item">
        <span class="legend-swatch" style="background:#6a9955;"></span> Type inference
      </div>
      <div class="legend-item">
        <span class="legend-swatch" style="background:#888;"></span> Infrastructure
      </div>
      <div class="legend-item">
        <span class="legend-swatch" style="background:#b48ead;"></span> Multiplicity
      </div>
      <div class="legend-item">
        <span class="legend-swatch" style="background:#f44;"></span> Contradiction
      </div>
      <div class="legend-item">
        <span class="legend-diamond" style="background:#569cd6;"></span> Propagator
      </div>
    </div>
  </div>

  <div class="tables">
    ${rounds.length > 0 ? `
    <details>
      <summary><strong>BSP Rounds (${rounds.length})</strong></summary>
      <table>
        <tr><th>Round</th><th>Fired</th><th>Diffs</th><th>Status</th></tr>
        ${roundRows}
      </table>
    </details>` : ''}
    <details>
      <summary><strong>Cells (${net.cells.length})</strong></summary>
      <table>
        <tr><th>ID</th><th>Subsystem</th><th>Value</th></tr>
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
  </div>

  <script>
  (function() {
    const trace = ${traceDataJson};
    const net = trace.finalNetwork;
    const cells = net.cells;
    const propagators = net.propagators;
    const contradiction = net.stats.contradiction;

    // ========================================
    // Layout: Topological layering for bipartite DAG
    // ========================================

    // Build node list: cells + propagators as distinct node types
    const nodes = [];
    const nodeById = {};

    cells.forEach(c => {
      const isSolved = c.value !== '\\u22a5' && c.value !== 'bot';
      const isContra = contradiction !== null && c.id === contradiction;
      const subsystem = c.subsystem || 'unknown';
      // Short label: show value snippet if it's compact, otherwise ID
      let label = '#' + c.id;
      if (c.value.length <= 12 && c.value !== '\\u22a5') {
        label = c.value;
      } else if (c.value.length <= 20) {
        label = c.value.substring(0, 12) + '..';
      }
      const node = {
        id: 'c' + c.id,
        type: 'cell',
        cellId: c.id,
        label: label,
        value: c.value,
        subsystem: subsystem,
        source: c.source || '',
        solved: isSolved,
        contradiction: isContra,
        x: 0, y: 0,
        layer: -1,
      };
      nodes.push(node);
      nodeById['c' + c.id] = node;
    });

    propagators.forEach(p => {
      const node = {
        id: 'p' + p.id,
        type: 'propagator',
        propId: p.id,
        label: 'P' + p.id,
        inputs: p.inputs,
        outputs: p.outputs,
        x: 0, y: 0,
        layer: -1,
      };
      nodes.push(node);
      nodeById['p' + p.id] = node;
    });

    // Build edges: cell → propagator (input), propagator → cell (output)
    const edges = [];
    propagators.forEach(p => {
      p.inputs.forEach(cid => {
        edges.push({ from: 'c' + cid, to: 'p' + p.id });
      });
      p.outputs.forEach(cid => {
        edges.push({ from: 'p' + p.id, to: 'c' + cid });
      });
    });

    // Topological layering via BFS from sources
    // Build adjacency
    const adj = {};
    const inDeg = {};
    nodes.forEach(n => { adj[n.id] = []; inDeg[n.id] = 0; });
    edges.forEach(e => {
      adj[e.from].push(e.to);
      inDeg[e.to] = (inDeg[e.to] || 0) + 1;
    });

    // Kahn's algorithm for layering
    let queue = nodes.filter(n => inDeg[n.id] === 0).map(n => n.id);
    let layer = 0;
    while (queue.length > 0) {
      const nextQueue = [];
      queue.forEach(nid => {
        nodeById[nid].layer = layer;
        adj[nid].forEach(toId => {
          inDeg[toId]--;
          if (inDeg[toId] === 0) {
            nextQueue.push(toId);
          }
        });
      });
      queue = nextQueue;
      layer++;
    }
    // Handle cycles: assign remaining to last layer
    nodes.forEach(n => { if (n.layer === -1) n.layer = layer; });

    const numLayers = layer || 1;

    // Position nodes within layers
    const layerNodes = {};
    nodes.forEach(n => {
      if (!layerNodes[n.layer]) layerNodes[n.layer] = [];
      layerNodes[n.layer].push(n);
    });

    // Layout parameters
    const CELL_R = 16;
    const PROP_R = 12;
    const H_SPACING = 60;
    const V_SPACING = 60;
    const PADDING = 60;

    // If no edges, use grid layout instead of single-line layering
    if (edges.length === 0 && nodes.length > 0) {
      const cols = Math.ceil(Math.sqrt(nodes.length * 1.5));
      nodes.forEach((n, i) => {
        n.x = (i % cols) * H_SPACING;
        n.y = Math.floor(i / cols) * V_SPACING;
      });
    } else {
      // Assign positions within layers
      for (let l = 0; l < numLayers; l++) {
        const layerArr = layerNodes[l] || [];
        const layerWidth = (layerArr.length - 1) * H_SPACING;
        const startX = -layerWidth / 2;
        layerArr.forEach((n, i) => {
          n.x = startX + i * H_SPACING;
          n.y = l * V_SPACING;
        });
      }
    }

    // Center the graph
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    nodes.forEach(n => {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    });
    const graphW = (maxX - minX) + PADDING * 2;
    const graphH = (maxY - minY) + PADDING * 2;
    const offsetX = -minX + PADDING;
    const offsetY = -minY + PADDING;
    nodes.forEach(n => { n.x += offsetX; n.y += offsetY; });

    // ========================================
    // Canvas Rendering
    // ========================================

    const container = document.getElementById('graph-container');
    const canvas = document.getElementById('graph-canvas');
    const tooltip = document.getElementById('tooltip');
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;

    function resize() {
      const rect = container.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      canvas.style.width = rect.width + 'px';
      canvas.style.height = rect.height + 'px';
    }
    resize();
    window.addEventListener('resize', () => { resize(); draw(); });

    // Colors — subsystem-based palette
    const SUBSYSTEM_COLORS = {
      'type-inference':  { solved: '#6a9955', unsolved: '#4a6a3a' },
      'infrastructure':  { solved: '#888',    unsolved: '#555'    },
      'multiplicity':    { solved: '#b48ead', unsolved: '#7a5a7a' },
      'unknown':         { solved: '#569cd6', unsolved: '#3a6a9a' },
    };
    const COLORS = {
      cellContra: '#f44',
      propagator: '#569cd6',
      edge: '#555',
      edgeHighlight: '#ddd',
      text: getComputedStyle(document.body).color || '#ccc',
      textDim: '#999',
    };

    function cellColor(node) {
      if (node.contradiction) return COLORS.cellContra;
      const sub = SUBSYSTEM_COLORS[node.subsystem] || SUBSYSTEM_COLORS['unknown'];
      return node.solved ? sub.solved : sub.unsolved;
    }

    // Transform state (pan + zoom)
    let transform = { x: 0, y: 0, k: 1 };

    // Fit initial view
    function fitView() {
      const rect = container.getBoundingClientRect();
      const scaleX = rect.width / (graphW || 1);
      const scaleY = rect.height / (graphH || 1);
      const scale = Math.min(scaleX, scaleY, 2) * 0.85;
      transform.k = scale;
      transform.x = (rect.width - graphW * scale) / 2;
      transform.y = (rect.height - graphH * scale) / 2;
    }
    fitView();

    function toScreen(x, y) {
      return [x * transform.k + transform.x, y * transform.k + transform.y];
    }

    function toWorld(sx, sy) {
      return [(sx - transform.x) / transform.k, (sy - transform.y) / transform.k];
    }

    function drawArrow(ctx, x1, y1, x2, y2, headLen) {
      const dx = x2 - x1;
      const dy = y2 - y1;
      const len = Math.sqrt(dx * dx + dy * dy);
      if (len === 0) return;
      const ux = dx / len;
      const uy = dy / len;
      // Shorten line to not overlap node
      const sx1 = x1, sy1 = y1;
      const sx2 = x2, sy2 = y2;
      ctx.beginPath();
      ctx.moveTo(sx1, sy1);
      ctx.lineTo(sx2, sy2);
      ctx.stroke();
      // Arrowhead
      const angle = Math.atan2(dy, dx);
      ctx.beginPath();
      ctx.moveTo(sx2, sy2);
      ctx.lineTo(sx2 - headLen * Math.cos(angle - 0.35), sy2 - headLen * Math.sin(angle - 0.35));
      ctx.lineTo(sx2 - headLen * Math.cos(angle + 0.35), sy2 - headLen * Math.sin(angle + 0.35));
      ctx.closePath();
      ctx.fill();
    }

    function drawDiamond(ctx, cx, cy, r) {
      ctx.beginPath();
      ctx.moveTo(cx, cy - r);
      ctx.lineTo(cx + r, cy);
      ctx.lineTo(cx, cy + r);
      ctx.lineTo(cx - r, cy);
      ctx.closePath();
    }

    function draw() {
      const w = canvas.width;
      const h = canvas.height;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w / dpr, h / dpr);

      // Draw edges
      ctx.lineWidth = 1.2;
      edges.forEach(e => {
        const from = nodeById[e.from];
        const to = nodeById[e.to];
        if (!from || !to) return;
        const [fx, fy] = toScreen(from.x, from.y);
        const [tx, ty] = toScreen(to.x, to.y);

        // Shorten edge to node boundary
        const dx = tx - fx, dy = ty - fy;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (len < 1) return;
        const ux = dx / len, uy = dy / len;

        const fromR = (from.type === 'cell' ? CELL_R : PROP_R) * transform.k;
        const toR = (to.type === 'cell' ? CELL_R : PROP_R) * transform.k;
        const sx = fx + ux * fromR;
        const sy = fy + uy * fromR;
        const ex = tx - ux * toR;
        const ey = ty - uy * toR;

        const isHighlighted = hoveredNode &&
          (e.from === hoveredNode.id || e.to === hoveredNode.id);

        ctx.strokeStyle = isHighlighted ? COLORS.edgeHighlight : COLORS.edge;
        ctx.fillStyle = isHighlighted ? COLORS.edgeHighlight : COLORS.edge;
        ctx.globalAlpha = isHighlighted ? 1.0 : 0.5;
        drawArrow(ctx, sx, sy, ex, ey, 6 * transform.k);
        ctx.globalAlpha = 1.0;
      });

      // Draw nodes
      nodes.forEach(n => {
        const [sx, sy] = toScreen(n.x, n.y);
        const r = (n.type === 'cell' ? CELL_R : PROP_R) * transform.k;

        if (n.type === 'cell') {
          // Circle — color by subsystem
          ctx.beginPath();
          ctx.arc(sx, sy, r, 0, Math.PI * 2);
          ctx.fillStyle = cellColor(n);
          ctx.fill();
          ctx.strokeStyle = (hoveredNode && hoveredNode.id === n.id) ? '#fff' : 'rgba(255,255,255,0.3)';
          ctx.lineWidth = (hoveredNode && hoveredNode.id === n.id) ? 2 : 1;
          ctx.stroke();
        } else {
          // Diamond
          drawDiamond(ctx, sx, sy, r);
          ctx.fillStyle = COLORS.propagator;
          ctx.fill();
          ctx.strokeStyle = (hoveredNode && hoveredNode.id === n.id) ? '#fff' : 'rgba(255,255,255,0.3)';
          ctx.lineWidth = (hoveredNode && hoveredNode.id === n.id) ? 2 : 1;
          ctx.stroke();
        }

        // Label
        if (transform.k > 0.4) {
          const fontSize = Math.max(8, 10 * transform.k);
          ctx.font = fontSize + 'px ' +
            (getComputedStyle(document.body).fontFamily || 'sans-serif');
          ctx.textAlign = 'center';
          // Draw label below the node for cells (so circle stays clean)
          if (n.type === 'cell' && edges.length === 0) {
            ctx.textBaseline = 'top';
            ctx.fillStyle = COLORS.textDim;
            const labelText = n.label.length > 14 ? n.label.substring(0, 12) + '..' : n.label;
            ctx.fillText(labelText, sx, sy + r + 3 * transform.k);
          } else {
            ctx.textBaseline = 'middle';
            ctx.fillStyle = COLORS.text;
            ctx.fillText(n.label, sx, sy);
          }
        }
      });
    }

    // ========================================
    // Hit Testing (quadtree-free, simple for small graphs)
    // ========================================

    let hoveredNode = null;

    function hitTest(mx, my) {
      const [wx, wy] = toWorld(mx, my);
      let best = null;
      let bestDist = Infinity;
      nodes.forEach(n => {
        const dx = wx - n.x;
        const dy = wy - n.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const r = n.type === 'cell' ? CELL_R : PROP_R;
        if (dist < r * 1.5 && dist < bestDist) {
          best = n;
          bestDist = dist;
        }
      });
      return best;
    }

    canvas.addEventListener('mousemove', (e) => {
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const hit = hitTest(mx, my);
      if (hit !== hoveredNode) {
        hoveredNode = hit;
        draw();
        if (hit) {
          let html = '';
          if (hit.type === 'cell') {
            html = '<strong>Cell #' + hit.cellId + '</strong>\\n'
              + 'Subsystem: ' + (hit.subsystem || 'unknown') + '\\n'
              + (hit.source ? 'Source: ' + escapeHtmlInline(hit.source) + '\\n' : '')
              + 'Value: ' + escapeHtmlInline(hit.value);
          } else {
            html = '<strong>Propagator P' + hit.propId + '</strong>\\n'
              + 'Inputs: ' + hit.inputs.map(i => '#' + i).join(', ') + '\\n'
              + 'Outputs: ' + hit.outputs.map(o => '#' + o).join(', ');
          }
          tooltip.innerHTML = html;
          tooltip.style.display = 'block';
          tooltip.style.left = (mx + 12) + 'px';
          tooltip.style.top = (my - 8) + 'px';
        } else {
          tooltip.style.display = 'none';
        }
      } else if (hit) {
        tooltip.style.left = (mx + 12) + 'px';
        tooltip.style.top = (my - 8) + 'px';
      }
    });

    canvas.addEventListener('mouseleave', () => {
      hoveredNode = null;
      tooltip.style.display = 'none';
      draw();
    });

    function escapeHtmlInline(s) {
      return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    // ========================================
    // Zoom + Pan (manual, d3-zoom if available)
    // ========================================

    if (typeof d3 !== 'undefined' && d3.zoom) {
      // Use d3-zoom for smooth interaction
      const sel = d3.select(canvas);
      const zoom = d3.zoom()
        .scaleExtent([0.1, 5])
        .on('zoom', (event) => {
          transform.x = event.transform.x;
          transform.y = event.transform.y;
          transform.k = event.transform.k;
          draw();
        });
      sel.call(zoom);
      // Set initial transform
      sel.call(zoom.transform,
        d3.zoomIdentity.translate(transform.x, transform.y).scale(transform.k));
    } else {
      // Fallback: manual wheel zoom + drag pan
      let isPanning = false;
      let panStart = { x: 0, y: 0 };

      canvas.addEventListener('wheel', (e) => {
        e.preventDefault();
        const rect = canvas.getBoundingClientRect();
        const mx = e.clientX - rect.left;
        const my = e.clientY - rect.top;
        const factor = e.deltaY < 0 ? 1.1 : 0.9;
        const newK = Math.max(0.1, Math.min(5, transform.k * factor));
        // Zoom toward cursor
        transform.x = mx - (mx - transform.x) * (newK / transform.k);
        transform.y = my - (my - transform.y) * (newK / transform.k);
        transform.k = newK;
        draw();
      }, { passive: false });

      canvas.addEventListener('mousedown', (e) => {
        if (e.button === 0) {
          isPanning = true;
          panStart = { x: e.clientX - transform.x, y: e.clientY - transform.y };
        }
      });
      window.addEventListener('mousemove', (e) => {
        if (isPanning) {
          transform.x = e.clientX - panStart.x;
          transform.y = e.clientY - panStart.y;
          draw();
        }
      });
      window.addEventListener('mouseup', () => { isPanning = false; });
    }

    // Initial draw
    draw();
  })();
  </script>
</body>
</html>`;
  }

  /**
   * Render the Observatory multi-network view.
   * Shows a capture selector, per-subsystem color coding, and graph for selected capture.
   */
  private renderObservatory(obs: ObservatoryJson): string {
    const d3Uri = this.getD3Uri();
    const captures = obs.observatory.captures;
    const links = obs.observatory.links;
    const meta = obs.observatory.metadata;

    if (captures.length === 0) {
      return this.renderError('No network captures in observatory.');
    }

    // Subsystem color palette
    const SUBSYSTEM_PALETTE: Record<string, string> = {
      'type-inference': '#6a9955',
      'session':        '#569cd6',
      'capability':     '#d7ba7d',
      'user':           '#c586c0',
      'narrowing':      '#4ec9b0',
    };

    // Build capture options for the selector, sorted: captures with propagators first
    const captureIndices = captures.map((_, i) => i);
    captureIndices.sort((a, b) => {
      const pa = captures[a].network.propagators.length;
      const pb = captures[b].network.propagators.length;
      if (pb !== pa) return pb - pa; // More propagators first
      return a - b; // Then by original order
    });
    const captureOptions = captureIndices.map(i => {
      const cap = captures[i];
      const statusIcon = cap.status === 'exception' ? '\u26a0' : '\u2713';
      const propCount = cap.network.propagators.length;
      const propSuffix = propCount > 0 ? ` (${cap.network.cells.length}c/${propCount}p)` : '';
      return `<option value="${i}">[${cap.subsystem}] ${escapeHtml(cap.label)}${propSuffix} ${statusIcon}</option>`;
    }).join('\n');
    const defaultCapture = captureIndices[0];

    // Serialize all captures for the webview script
    const obsDataJson = JSON.stringify(obs).replace(/</g, '\\u003c');

    // Build subsystem legend items from actually present subsystems
    const legendItems = meta.subsystems.map(sub => {
      const color = SUBSYSTEM_PALETTE[sub] || '#888';
      return `<div class="legend-item">
        <span class="legend-swatch" style="background:${color};"></span> ${escapeHtml(sub)}
      </div>`;
    }).join('\n');

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  ${d3Uri ? `<script src="${d3Uri}"></script>` : ''}
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: var(--vscode-font-family, sans-serif);
      color: var(--vscode-foreground, #ccc);
      background: var(--vscode-editor-background, #1e1e1e);
      padding: 0; margin: 0;
      overflow: hidden; height: 100vh;
      display: flex; flex-direction: column;
    }
    .header {
      padding: 8px 16px;
      display: flex; align-items: center; gap: 12px;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0; flex-wrap: wrap;
    }
    h2 { margin: 0; font-size: 1.1em; }
    .stats { display: flex; gap: 8px; flex-wrap: wrap; }
    .stat {
      padding: 3px 8px;
      background: var(--vscode-textBlockQuote-background, #252526);
      border-radius: 4px; font-size: 0.85em;
    }
    .stat-value { font-weight: bold; margin-right: 4px; }
    .stat-label { opacity: 0.7; }
    .capture-selector {
      padding: 4px 8px;
      background: var(--vscode-input-background, #3c3c3c);
      color: var(--vscode-input-foreground, #ccc);
      border: 1px solid var(--vscode-input-border, #555);
      border-radius: 4px; font-size: 0.85em;
      min-width: 200px;
    }
    .capture-info {
      padding: 4px 16px;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
      font-size: 0.8em; opacity: 0.8;
      flex-shrink: 0;
    }
    .capture-info span { margin-right: 16px; }
    .status-ok { color: #6a9955; }
    .status-exception { color: #f44; }
    .graph-container { flex: 1; position: relative; overflow: hidden; }
    canvas { display: block; width: 100%; height: 100%; }
    .tooltip {
      position: absolute; pointer-events: none;
      background: var(--vscode-editorHoverWidget-background, #252526);
      border: 1px solid var(--vscode-editorHoverWidget-border, #454545);
      color: var(--vscode-editorHoverWidget-foreground, #ccc);
      padding: 8px 12px; border-radius: 4px;
      font-size: 12px; font-family: var(--vscode-editor-font-family, monospace);
      max-width: 500px; white-space: pre-wrap; word-break: break-word;
      display: none; z-index: 10;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .subsystem-filters {
      padding: 4px 16px;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0; display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
      font-size: 0.8em;
    }
    .subsystem-filters label { display: flex; align-items: center; gap: 4px; cursor: pointer; opacity: 0.85; }
    .subsystem-filters label:hover { opacity: 1; }
    .subsystem-filters input[type="checkbox"] { accent-color: var(--vscode-focusBorder, #007acc); }
    .filter-label { font-size: 0.75em; opacity: 0.6; text-transform: uppercase; letter-spacing: 0.5px; }
    .legend {
      position: absolute; bottom: 8px; left: 8px;
      background: var(--vscode-textBlockQuote-background, #252526);
      border: 1px solid var(--vscode-widget-border, #333);
      border-radius: 4px; padding: 6px 10px;
      font-size: 11px; opacity: 0.85; z-index: 5;
    }
    .legend-item { display: flex; align-items: center; gap: 6px; margin: 2px 0; }
    .legend-swatch { width: 12px; height: 12px; border-radius: 50%; display: inline-block; }
    .legend-diamond { width: 12px; height: 12px; display: inline-block; transform: rotate(45deg); }
    .timeline-bar {
      padding: 6px 16px;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0; display: none;
      align-items: center; gap: 12px;
    }
    .timeline-bar.visible { display: flex; flex-wrap: wrap; }
    .timeline-bar label { font-size: 0.8em; opacity: 0.7; white-space: nowrap; }
    .timeline-slider {
      flex: 1; min-width: 120px;
      accent-color: var(--vscode-focusBorder, #007acc);
    }
    .round-info {
      font-size: 0.8em; display: flex; gap: 10px; flex-wrap: wrap;
    }
    .round-info .ri-item { white-space: nowrap; }
    .round-info .ri-value { font-weight: bold; }
    .round-diff-table {
      font-size: 0.8em; max-height: 120px; overflow-y: auto;
      border-top: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0; display: none;
    }
    .round-diff-table.visible { display: block; }
    .round-diff-table table { border-collapse: collapse; width: 100%; }
    .round-diff-table th, .round-diff-table td {
      padding: 2px 6px; text-align: left;
      border-bottom: 1px solid var(--vscode-widget-border, #333);
    }
    .round-diff-table th { opacity: 0.7; font-size: 0.9em; }
    .diff-old { color: #f44; text-decoration: line-through; opacity: 0.7; }
    .diff-new { color: #6a9955; }
    .tables {
      max-height: 35vh; overflow-y: auto;
      padding: 8px 16px;
      border-top: 1px solid var(--vscode-widget-border, #333);
      flex-shrink: 0;
    }
    h3 { margin: 8px 0 4px 0; font-size: 0.9em; opacity: 0.8; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 8px; }
    th, td { padding: 3px 6px; text-align: left; border-bottom: 1px solid var(--vscode-widget-border, #333); font-size: 0.85em; }
    th { opacity: 0.7; font-size: 0.8em; }
    code { font-family: var(--vscode-editor-font-family, monospace); font-size: 0.9em; }
    details { margin-bottom: 4px; }
    summary { cursor: pointer; opacity: 0.8; font-size: 0.9em; }
    summary:hover { opacity: 1; }
  </style>
</head>
<body>
  <div class="header">
    <h2>Observatory</h2>
    <select class="capture-selector" id="capture-selector">
      ${captureOptions}
    </select>
    <div class="stats">
      <div class="stat">
        <span class="stat-value">${meta.totalCaptures}</span>
        <span class="stat-label">Captures</span>
      </div>
      <div class="stat">
        <span class="stat-value">${links.length}</span>
        <span class="stat-label">Links</span>
      </div>
      <div class="stat">
        <span class="stat-value">${meta.subsystems.length}</span>
        <span class="stat-label">Subsystems</span>
      </div>
    </div>
  </div>
  <div class="subsystem-filters" id="subsystem-filters">
    <span class="filter-label">Filter:</span>
  </div>
  <div class="capture-info" id="capture-info"></div>

  <div class="timeline-bar" id="timeline-bar">
    <label>Round:</label>
    <input type="range" class="timeline-slider" id="timeline-slider" min="0" max="0" step="1" value="0">
    <div class="round-info" id="round-info"></div>
  </div>

  <div class="round-diff-table" id="round-diff-table"></div>

  <div class="graph-container" id="graph-container">
    <canvas id="graph-canvas"></canvas>
    <div class="tooltip" id="tooltip"></div>
    <div class="legend">
      ${legendItems}
      <div class="legend-item">
        <span class="legend-diamond" style="background:#569cd6;"></span> Propagator
      </div>
    </div>
  </div>

  <div class="tables" id="tables"></div>

  <script>
  (function() {
    const obsData = ${obsDataJson};
    const captures = obsData.observatory.captures;
    const links = obsData.observatory.links;

    // Subsystem color palette
    const SUBSYSTEM_PALETTE = {
      'type-inference': '#6a9955',
      'session':        '#569cd6',
      'capability':     '#d7ba7d',
      'user':           '#c586c0',
      'narrowing':      '#4ec9b0',
    };

    const container = document.getElementById('graph-container');
    const canvas = document.getElementById('graph-canvas');
    const tooltip = document.getElementById('tooltip');
    const captureInfo = document.getElementById('capture-info');
    const tablesDiv = document.getElementById('tables');
    const selector = document.getElementById('capture-selector');
    const timelineBar = document.getElementById('timeline-bar');
    const timelineSlider = document.getElementById('timeline-slider');
    const roundInfoDiv = document.getElementById('round-info');
    const roundDiffDiv = document.getElementById('round-diff-table');
    const filtersDiv = document.getElementById('subsystem-filters');
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;

    let currentNodes = [];
    let currentEdges = [];
    let nodeById = {};
    let hoveredNode = null;
    let transform = { x: 0, y: 0, k: 1 };

    // Timeline state
    let currentTrace = null;        // PropTraceJson for current capture (null if no trace)
    let currentRound = -1;          // -1 = final, 0 = initial, 1..N = after round N
    let changedCellIds = new Set();  // Cell IDs that changed in the current round
    let initialCellValues = {};      // cellId -> initial value (from trace.initialNetwork)

    // Pre-sorted capture indices (captures with most propagators first)
    const captureIndices = captures.map((_, i) => i);
    captureIndices.sort((a, b) => {
      const pa = captures[a].network.propagators.length;
      const pb = captures[b].network.propagators.length;
      if (pb !== pa) return pb - pa;
      return a - b;
    });

    // Subsystem filter state
    const enabledSubsystems = {};
    const allSubsystems = obsData.observatory.metadata.subsystems || [];
    allSubsystems.forEach(sub => { enabledSubsystems[sub] = true; });

    // Rebuild the capture dropdown based on active subsystem filters
    function rebuildCaptureSelector() {
      const currentVal = parseInt(selector.value) || 0;
      const filtered = captureIndices.filter(i => enabledSubsystems[captures[i].subsystem] !== false);
      selector.innerHTML = filtered.map(i => {
        const cap = captures[i];
        const statusIcon = cap.status === 'exception' ? '\\u26a0' : '\\u2713';
        const propCount = cap.network.propagators.length;
        const propSuffix = propCount > 0 ? ' (' + cap.network.cells.length + 'c/' + propCount + 'p)' : '';
        return '<option value="' + i + '">[' + cap.subsystem + '] ' + escapeHtmlInline(cap.label) + propSuffix + ' ' + statusIcon + '</option>';
      }).join('\\n');

      // Try to preserve selection; if not available, select first
      if (filtered.includes(currentVal)) {
        selector.value = String(currentVal);
      } else if (filtered.length > 0) {
        selector.value = String(filtered[0]);
        loadCapture(filtered[0]);
      }
    }

    // Build filter checkboxes
    allSubsystems.forEach(sub => {
      const label = document.createElement('label');
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = true;
      cb.dataset.subsystem = sub;
      const swatchColor = SUBSYSTEM_PALETTE[sub] || '#888';
      label.appendChild(cb);
      const swatch = document.createElement('span');
      swatch.style.display = 'inline-block';
      swatch.style.width = '8px';
      swatch.style.height = '8px';
      swatch.style.borderRadius = '50%';
      swatch.style.background = swatchColor;
      label.appendChild(swatch);
      label.appendChild(document.createTextNode(' ' + sub));
      filtersDiv.appendChild(label);

      cb.addEventListener('change', () => {
        enabledSubsystems[sub] = cb.checked;
        rebuildCaptureSelector();
      });
    });

    const CELL_R = 16;
    const PROP_R = 12;
    const H_SPACING = 60;
    const V_SPACING = 60;
    const PADDING = 60;

    const COLORS = {
      cellContra: '#f44',
      propagator: '#569cd6',
      edge: '#555',
      edgeHighlight: '#ddd',
      text: getComputedStyle(document.body).color || '#ccc',
      textDim: '#999',
    };

    function resize() {
      const rect = container.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      canvas.style.width = rect.width + 'px';
      canvas.style.height = rect.height + 'px';
    }

    function cellColor(node, capSubsystem) {
      if (node.contradiction) return COLORS.cellContra;
      const sub = node.cellSubsystem || capSubsystem || 'unknown';
      const color = SUBSYSTEM_PALETTE[sub] || '#888';
      return node.solved ? color : adjustBrightness(color, -30);
    }

    function adjustBrightness(hex, amount) {
      const num = parseInt(hex.replace('#', ''), 16);
      const r = Math.max(0, Math.min(255, ((num >> 16) & 0xFF) + amount));
      const g = Math.max(0, Math.min(255, ((num >> 8) & 0xFF) + amount));
      const b = Math.max(0, Math.min(255, (num & 0xFF) + amount));
      return '#' + ((r << 16) | (g << 8) | b).toString(16).padStart(6, '0');
    }

    function loadCapture(index) {
      const cap = captures[index];
      const net = cap.network;
      const cells = net.cells;
      const propagators = net.propagators;
      const contradiction = net.stats ? net.stats.contradiction : null;

      // Update capture info bar
      const statusClass = cap.status === 'exception' ? 'status-exception' : 'status-ok';
      const statusText = cap.status === 'exception'
        ? 'Exception: ' + (cap.statusDetail || 'unknown')
        : 'Complete';
      captureInfo.innerHTML =
        '<span><strong>' + escapeHtmlInline(cap.label) + '</strong></span>' +
        '<span class="' + statusClass + '">' + statusText + '</span>' +
        '<span>Cells: ' + cells.length + '</span>' +
        '<span>Props: ' + propagators.length + '</span>' +
        '<span>Seq: ' + cap.sequenceNumber + '</span>';

      // Build nodes
      currentNodes = [];
      nodeById = {};

      cells.forEach(c => {
        const isSolved = c.value !== '\\u22a5' && c.value !== 'bot';
        const isContra = contradiction !== null && c.id === contradiction;
        const fullLabel = c.label || ('#' + c.id);
        let label = fullLabel;
        if (label.length > 24) label = label.substring(0, 22) + '..';
        const node = {
          id: 'c' + c.id, type: 'cell', cellId: c.id,
          label: label, fullLabel: fullLabel, value: c.value,
          cellSubsystem: c.cellSubsystem || c.subsystem || cap.subsystem,
          domain: c.domain || '',
          source: c.source || '',
          sourceLoc: c.cellSourceLoc || null,
          solved: isSolved, contradiction: isContra,
          x: 0, y: 0, layer: -1,
        };
        currentNodes.push(node);
        nodeById['c' + c.id] = node;
      });

      propagators.forEach(p => {
        const node = {
          id: 'p' + p.id, type: 'propagator', propId: p.id,
          label: 'P' + p.id,
          inputs: p.inputs, outputs: p.outputs,
          x: 0, y: 0, layer: -1,
        };
        currentNodes.push(node);
        nodeById['p' + p.id] = node;
      });

      // Build edges
      currentEdges = [];
      propagators.forEach(p => {
        p.inputs.forEach(cid => { currentEdges.push({ from: 'c' + cid, to: 'p' + p.id }); });
        p.outputs.forEach(cid => { currentEdges.push({ from: 'p' + p.id, to: 'c' + cid }); });
      });

      // Topological layering
      const adj = {};
      const inDeg = {};
      currentNodes.forEach(n => { adj[n.id] = []; inDeg[n.id] = 0; });
      currentEdges.forEach(e => { adj[e.from].push(e.to); inDeg[e.to] = (inDeg[e.to] || 0) + 1; });

      let queue = currentNodes.filter(n => inDeg[n.id] === 0).map(n => n.id);
      let layer = 0;
      while (queue.length > 0) {
        const nextQueue = [];
        queue.forEach(nid => {
          nodeById[nid].layer = layer;
          adj[nid].forEach(toId => {
            inDeg[toId]--;
            if (inDeg[toId] === 0) nextQueue.push(toId);
          });
        });
        queue = nextQueue;
        layer++;
      }
      currentNodes.forEach(n => { if (n.layer === -1) n.layer = layer; });

      const numLayers = layer || 1;
      const layerNodes = {};
      currentNodes.forEach(n => {
        if (!layerNodes[n.layer]) layerNodes[n.layer] = [];
        layerNodes[n.layer].push(n);
      });

      if (currentEdges.length === 0 && currentNodes.length > 0) {
        // Grid layout for disconnected nodes
        const cols = Math.ceil(Math.sqrt(currentNodes.length * 1.5));
        currentNodes.forEach((n, i) => {
          n.x = (i % cols) * H_SPACING;
          n.y = Math.floor(i / cols) * V_SPACING;
        });
      } else if (currentNodes.length > 100) {
        // Force-directed layout for large connected graphs
        // Initialize with layered positions (wider spread)
        const maxLayerSize = Math.max(...Object.values(layerNodes).map(arr => arr.length), 1);
        for (let l = 0; l < numLayers; l++) {
          const arr = layerNodes[l] || [];
          arr.forEach((n, i) => {
            n.x = (i - arr.length / 2) * H_SPACING * 0.8 + (Math.random() - 0.5) * 20;
            n.y = l * V_SPACING * 2;
          });
        }
        // Simple force simulation (repulsion + edge attraction)
        const iterations = 80;
        const repulsion = 800;
        const attraction = 0.05;
        const damping = 0.85;
        const vx = {}, vy = {};
        currentNodes.forEach(n => { vx[n.id] = 0; vy[n.id] = 0; });

        for (let iter = 0; iter < iterations; iter++) {
          const temp = 1 - iter / iterations;
          // Repulsion between nearby nodes (skip distant pairs for O(n) perf)
          const cutoff = 200;
          for (let i = 0; i < currentNodes.length; i++) {
            for (let j = i + 1; j < currentNodes.length; j++) {
              const a = currentNodes[i], b = currentNodes[j];
              let dx = b.x - a.x, dy = b.y - a.y;
              if (Math.abs(dx) > cutoff || Math.abs(dy) > cutoff) continue;
              const dist = Math.max(Math.sqrt(dx * dx + dy * dy), 1);
              if (dist > cutoff) continue;
              const force = repulsion / (dist * dist) * temp;
              const fx = (dx / dist) * force, fy = (dy / dist) * force;
              vx[a.id] -= fx; vy[a.id] -= fy;
              vx[b.id] += fx; vy[b.id] += fy;
            }
          }
          // Attraction along edges
          currentEdges.forEach(e => {
            const a = nodeById[e.from], b = nodeById[e.to];
            if (!a || !b) return;
            const dx = b.x - a.x, dy = b.y - a.y;
            const fx = dx * attraction * temp, fy = dy * attraction * temp;
            vx[a.id] += fx; vy[a.id] += fy;
            vx[b.id] -= fx; vy[b.id] -= fy;
          });
          // Layer constraint: gently pull nodes toward their layer's Y
          currentNodes.forEach(n => {
            const targetY = n.layer * V_SPACING * 2;
            vy[n.id] += (targetY - n.y) * 0.1 * temp;
          });
          // Apply velocities
          currentNodes.forEach(n => {
            vx[n.id] *= damping; vy[n.id] *= damping;
            n.x += vx[n.id]; n.y += vy[n.id];
          });
        }
      } else {
        // Standard layered layout for small graphs
        for (let l = 0; l < numLayers; l++) {
          const arr = layerNodes[l] || [];
          const w = (arr.length - 1) * H_SPACING;
          const startX = -w / 2;
          arr.forEach((n, i) => { n.x = startX + i * H_SPACING; n.y = l * V_SPACING; });
        }
      }

      // Center
      let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
      currentNodes.forEach(n => {
        if (n.x < minX) minX = n.x; if (n.x > maxX) maxX = n.x;
        if (n.y < minY) minY = n.y; if (n.y > maxY) maxY = n.y;
      });
      const graphW = (maxX - minX) + PADDING * 2;
      const graphH = (maxY - minY) + PADDING * 2;
      const offsetX = -minX + PADDING;
      const offsetY = -minY + PADDING;
      currentNodes.forEach(n => { n.x += offsetX; n.y += offsetY; });

      // Fit view
      const rect = container.getBoundingClientRect();
      const scaleX = rect.width / (graphW || 1);
      const scaleY = rect.height / (graphH || 1);
      const scale = Math.min(scaleX, scaleY, 2) * 0.85;
      transform = {
        k: scale,
        x: (rect.width - graphW * scale) / 2,
        y: (rect.height - graphH * scale) / 2,
      };

      // Build tables
      const cellRows = cells.map(c => {
        const val = c.value.length > 40 ? c.value.substring(0, 40) + '..' : c.value;
        const lbl = c.label || '#' + c.id;
        return '<tr><td>#' + c.id + '</td><td>' + escapeHtmlInline(lbl) + '</td><td><code>' + escapeHtmlInline(val) + '</code></td></tr>';
      }).join('');
      const cellLabelMap = {};
      cells.forEach(c => { cellLabelMap[c.id] = c.label || '#' + c.id; });
      const propRows = propagators.map(p => {
        const ins = p.inputs.map(i => '#' + i + ' <span style="opacity:0.6">(' + escapeHtmlInline(cellLabelMap[i] || '?') + ')</span>').join(', ');
        const outs = p.outputs.map(o => '#' + o + ' <span style="opacity:0.6">(' + escapeHtmlInline(cellLabelMap[o] || '?') + ')</span>').join(', ');
        return '<tr><td>P' + p.id + '</td><td>' + ins + '</td><td>' + outs + '</td></tr>';
      }).join('');

      tablesDiv.innerHTML =
        '<details><summary><strong>Cells (' + cells.length + ')</strong></summary>' +
        '<table><tr><th>ID</th><th>Label</th><th>Value</th></tr>' + cellRows + '</table></details>' +
        '<details><summary><strong>Propagators (' + propagators.length + ')</strong></summary>' +
        '<table><tr><th>ID</th><th>Inputs</th><th>Outputs</th></tr>' + propRows + '</table></details>';

      hoveredNode = null;

      // Timeline: check if this capture has trace data
      currentTrace = cap.trace || null;
      changedCellIds = new Set();
      initialCellValues = {};

      if (currentTrace && currentTrace.rounds && currentTrace.rounds.length > 0) {
        // Build initial cell value map from trace.initialNetwork
        if (currentTrace.initialNetwork && currentTrace.initialNetwork.cells) {
          currentTrace.initialNetwork.cells.forEach(c => {
            initialCellValues[c.id] = c.value;
          });
        }
        // Show timeline bar
        const maxRound = currentTrace.rounds.length;
        timelineSlider.max = String(maxRound);
        timelineSlider.value = String(maxRound); // Start at final state
        currentRound = maxRound;
        timelineBar.classList.add('visible');
        updateRoundInfo(maxRound);
      } else {
        // No trace — hide timeline
        currentTrace = null;
        currentRound = -1;
        timelineBar.classList.remove('visible');
        roundDiffDiv.classList.remove('visible');
      }

      draw();
    }

    // Apply cell diffs up to round K and update node values
    function applyDiffsToRound(roundIndex) {
      if (!currentTrace) return;
      const rounds = currentTrace.rounds;

      // Reset all cells to initial values
      currentNodes.forEach(n => {
        if (n.type === 'cell' && initialCellValues.hasOwnProperty(n.cellId)) {
          n.value = initialCellValues[n.cellId];
          n.solved = n.value !== '\\u22a5' && n.value !== 'bot';
        }
      });

      changedCellIds = new Set();

      // Apply diffs from round 1..roundIndex
      for (let r = 0; r < roundIndex && r < rounds.length; r++) {
        const round = rounds[r];
        if (round.cellDiffs) {
          round.cellDiffs.forEach(diff => {
            const node = nodeById['c' + diff.cellId];
            if (node) {
              node.value = diff.newValue;
              node.solved = diff.newValue !== '\\u22a5' && diff.newValue !== 'bot';
            }
          });
        }
      }

      // Mark cells that changed in this specific round (for highlighting)
      if (roundIndex > 0 && roundIndex <= rounds.length) {
        const round = rounds[roundIndex - 1];
        if (round.cellDiffs) {
          round.cellDiffs.forEach(diff => {
            changedCellIds.add(diff.cellId);
          });
        }
      }
    }

    function updateRoundInfo(roundIndex) {
      if (!currentTrace || !currentTrace.rounds) return;
      const rounds = currentTrace.rounds;
      const maxRound = rounds.length;

      if (roundIndex === 0) {
        roundInfoDiv.innerHTML =
          '<span class="ri-item"><span class="ri-value">Initial</span> state (before propagation)</span>';
        roundDiffDiv.classList.remove('visible');
      } else if (roundIndex <= maxRound) {
        const round = rounds[roundIndex - 1];
        const diffs = round.cellDiffs ? round.cellDiffs.length : 0;
        const fired = round.propagatorsFired ? round.propagatorsFired.length : 0;
        const contra = round.contradiction !== null && round.contradiction !== undefined;
        roundInfoDiv.innerHTML =
          '<span class="ri-item">Round <span class="ri-value">' + roundIndex + '</span>/' + maxRound + '</span>' +
          '<span class="ri-item"><span class="ri-value">' + diffs + '</span> diffs</span>' +
          '<span class="ri-item"><span class="ri-value">' + fired + '</span> fired</span>' +
          (contra ? '<span class="ri-item" style="color:#f44;">⚠ Contradiction</span>' : '');

        // Show diff table for this round
        if (diffs > 0) {
          const cellLabelMap = {};
          currentNodes.forEach(n => { if (n.type === 'cell') cellLabelMap[n.cellId] = n.fullLabel || n.label; });
          const rows = round.cellDiffs.map(d => {
            const lbl = cellLabelMap[d.cellId] || '#' + d.cellId;
            const oldVal = d.oldValue.length > 30 ? d.oldValue.substring(0, 28) + '..' : d.oldValue;
            const newVal = d.newValue.length > 30 ? d.newValue.substring(0, 28) + '..' : d.newValue;
            return '<tr><td>#' + d.cellId + '</td><td>' + escapeHtmlInline(lbl) + '</td>' +
              '<td><span class="diff-old">' + escapeHtmlInline(oldVal) + '</span></td>' +
              '<td><span class="diff-new">' + escapeHtmlInline(newVal) + '</span></td>' +
              '<td>P' + d.sourcePropagator + '</td></tr>';
          }).join('');
          roundDiffDiv.innerHTML =
            '<table><tr><th>ID</th><th>Cell</th><th>Old</th><th>New</th><th>Source</th></tr>' + rows + '</table>';
          roundDiffDiv.classList.add('visible');
        } else {
          roundDiffDiv.classList.remove('visible');
        }
      } else {
        roundInfoDiv.innerHTML =
          '<span class="ri-item"><span class="ri-value">Final</span> state</span>';
        roundDiffDiv.classList.remove('visible');
      }
    }

    // Timeline slider event handler
    timelineSlider.addEventListener('input', () => {
      const val = parseInt(timelineSlider.value) || 0;
      currentRound = val;
      applyDiffsToRound(val);
      updateRoundInfo(val);
      draw();
    });

    function toScreen(x, y) {
      return [x * transform.k + transform.x, y * transform.k + transform.y];
    }
    function toWorld(sx, sy) {
      return [(sx - transform.x) / transform.k, (sy - transform.y) / transform.k];
    }

    function drawArrow(ctx, x1, y1, x2, y2, headLen) {
      const dx = x2 - x1, dy = y2 - y1;
      const len = Math.sqrt(dx * dx + dy * dy);
      if (len === 0) return;
      ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
      const angle = Math.atan2(dy, dx);
      ctx.beginPath(); ctx.moveTo(x2, y2);
      ctx.lineTo(x2 - headLen * Math.cos(angle - 0.35), y2 - headLen * Math.sin(angle - 0.35));
      ctx.lineTo(x2 - headLen * Math.cos(angle + 0.35), y2 - headLen * Math.sin(angle + 0.35));
      ctx.closePath(); ctx.fill();
    }

    function drawDiamond(ctx, cx, cy, r) {
      ctx.beginPath();
      ctx.moveTo(cx, cy - r); ctx.lineTo(cx + r, cy);
      ctx.lineTo(cx, cy + r); ctx.lineTo(cx - r, cy);
      ctx.closePath();
    }

    function draw() {
      const w = canvas.width, h = canvas.height;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w / dpr, h / dpr);

      const capIndex = parseInt(selector.value) || 0;
      const capSub = captures[capIndex] ? captures[capIndex].subsystem : '';

      // Edges
      ctx.lineWidth = 1.2;
      currentEdges.forEach(e => {
        const from = nodeById[e.from], to = nodeById[e.to];
        if (!from || !to) return;
        const [fx, fy] = toScreen(from.x, from.y);
        const [tx, ty] = toScreen(to.x, to.y);
        const dx = tx - fx, dy = ty - fy;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (len < 1) return;
        const ux = dx / len, uy = dy / len;
        const fromR = (from.type === 'cell' ? CELL_R : PROP_R) * transform.k;
        const toR = (to.type === 'cell' ? CELL_R : PROP_R) * transform.k;
        const isHL = hoveredNode && (e.from === hoveredNode.id || e.to === hoveredNode.id);
        ctx.strokeStyle = isHL ? COLORS.edgeHighlight : COLORS.edge;
        ctx.fillStyle = isHL ? COLORS.edgeHighlight : COLORS.edge;
        ctx.globalAlpha = isHL ? 1.0 : 0.5;
        drawArrow(ctx, fx + ux * fromR, fy + uy * fromR, tx - ux * toR, ty - uy * toR, 6 * transform.k);
        ctx.globalAlpha = 1.0;
      });

      // Nodes
      currentNodes.forEach(n => {
        const [sx, sy] = toScreen(n.x, n.y);
        const r = (n.type === 'cell' ? CELL_R : PROP_R) * transform.k;
        if (n.type === 'cell') {
          const isChanged = changedCellIds.has(n.cellId);
          ctx.beginPath(); ctx.arc(sx, sy, r, 0, Math.PI * 2);
          ctx.fillStyle = cellColor(n, capSub); ctx.fill();
          if (isChanged) {
            // Highlight changed cells with bright yellow ring
            ctx.strokeStyle = '#ffd700';
            ctx.lineWidth = 3;
            ctx.stroke();
            // Outer glow
            ctx.beginPath(); ctx.arc(sx, sy, r + 3 * transform.k, 0, Math.PI * 2);
            ctx.strokeStyle = 'rgba(255, 215, 0, 0.4)';
            ctx.lineWidth = 2;
            ctx.stroke();
          } else {
            ctx.strokeStyle = (hoveredNode && hoveredNode.id === n.id) ? '#fff' : 'rgba(255,255,255,0.3)';
            ctx.lineWidth = (hoveredNode && hoveredNode.id === n.id) ? 2 : 1;
            ctx.stroke();
          }
        } else {
          drawDiamond(ctx, sx, sy, r);
          ctx.fillStyle = COLORS.propagator; ctx.fill();
          ctx.strokeStyle = (hoveredNode && hoveredNode.id === n.id) ? '#fff' : 'rgba(255,255,255,0.3)';
          ctx.lineWidth = (hoveredNode && hoveredNode.id === n.id) ? 2 : 1;
          ctx.stroke();
        }
        if (transform.k > 0.4) {
          const fontSize = Math.max(8, 10 * transform.k);
          ctx.font = fontSize + 'px ' + (getComputedStyle(document.body).fontFamily || 'sans-serif');
          ctx.textAlign = 'center';
          if (n.type === 'cell' && currentEdges.length === 0) {
            ctx.textBaseline = 'top'; ctx.fillStyle = COLORS.textDim;
            ctx.fillText(n.label, sx, sy + r + 3 * transform.k);
          } else {
            ctx.textBaseline = 'middle'; ctx.fillStyle = COLORS.text;
            ctx.fillText(n.label, sx, sy);
          }
        }
      });
    }

    // Hit testing
    function hitTest(mx, my) {
      const [wx, wy] = toWorld(mx, my);
      let best = null, bestDist = Infinity;
      currentNodes.forEach(n => {
        const dx = wx - n.x, dy = wy - n.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const r = n.type === 'cell' ? CELL_R : PROP_R;
        if (dist < r * 1.5 && dist < bestDist) { best = n; bestDist = dist; }
      });
      return best;
    }

    canvas.addEventListener('mousemove', (e) => {
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left, my = e.clientY - rect.top;
      const hit = hitTest(mx, my);
      if (hit !== hoveredNode) {
        hoveredNode = hit; draw();
        canvas.style.cursor = (hit && hit.type === 'cell' && hit.sourceLoc) ? 'pointer' : 'default';
        if (hit) {
          let html = '';
          if (hit.type === 'cell') {
            html = '<strong>Cell #' + hit.cellId + '</strong>\\n'
              + 'Label: ' + escapeHtmlInline(hit.fullLabel || hit.label) + '\\n'
              + 'Subsystem: ' + (hit.cellSubsystem || 'unknown') + '\\n'
              + (hit.domain ? 'Domain: ' + hit.domain + '\\n' : '')
              + 'Value: ' + escapeHtmlInline(hit.value)
              + (hit.sourceLoc ? '\\n<span style="color:#007acc;font-size:0.9em;">Click to jump to line ' + hit.sourceLoc.line + '</span>' : '');
          } else {
            const inputLabels = hit.inputs.map(i => {
              const cn = nodeById['c' + i];
              return '#' + i + (cn ? ' (' + escapeHtmlInline(cn.fullLabel || cn.label) + ')' : '');
            }).join('\\n  ');
            const outputLabels = hit.outputs.map(o => {
              const cn = nodeById['c' + o];
              return '#' + o + (cn ? ' (' + escapeHtmlInline(cn.fullLabel || cn.label) + ')' : '');
            }).join('\\n  ');
            html = '<strong>Propagator P' + hit.propId + '</strong>\\n'
              + 'Inputs:\\n  ' + inputLabels + '\\n'
              + 'Outputs:\\n  ' + outputLabels;
          }
          tooltip.innerHTML = html;
          tooltip.style.display = 'block';
          tooltip.style.left = (mx + 12) + 'px';
          tooltip.style.top = (my - 8) + 'px';
        } else { tooltip.style.display = 'none'; }
      } else if (hit) {
        tooltip.style.left = (mx + 12) + 'px';
        tooltip.style.top = (my - 8) + 'px';
      }
    });

    canvas.addEventListener('mouseleave', () => {
      hoveredNode = null; tooltip.style.display = 'none'; draw();
    });

    // Click handler for source-location linking
    const vscode = acquireVsCodeApi();
    canvas.addEventListener('click', (e) => {
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left, my = e.clientY - rect.top;
      const hit = hitTest(mx, my);
      if (hit && hit.type === 'cell' && hit.sourceLoc) {
        vscode.postMessage({
          type: 'revealSourceLocation',
          line: hit.sourceLoc.line,
          col: hit.sourceLoc.col,
        });
      }
    });

    function escapeHtmlInline(s) {
      return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    // Zoom + Pan
    if (typeof d3 !== 'undefined' && d3.zoom) {
      const sel = d3.select(canvas);
      const zoom = d3.zoom().scaleExtent([0.1, 5]).on('zoom', (event) => {
        transform.x = event.transform.x;
        transform.y = event.transform.y;
        transform.k = event.transform.k;
        draw();
      });
      sel.call(zoom);
      selector.addEventListener('change', () => {
        loadCapture(parseInt(selector.value) || 0);
        sel.call(zoom.transform, d3.zoomIdentity.translate(transform.x, transform.y).scale(transform.k));
      });
    } else {
      let isPanning = false, panStart = { x: 0, y: 0 };
      canvas.addEventListener('wheel', (e) => {
        e.preventDefault();
        const rect = canvas.getBoundingClientRect();
        const mx = e.clientX - rect.left, my = e.clientY - rect.top;
        const factor = e.deltaY < 0 ? 1.1 : 0.9;
        const newK = Math.max(0.1, Math.min(5, transform.k * factor));
        transform.x = mx - (mx - transform.x) * (newK / transform.k);
        transform.y = my - (my - transform.y) * (newK / transform.k);
        transform.k = newK; draw();
      }, { passive: false });
      canvas.addEventListener('mousedown', (e) => {
        if (e.button === 0) { isPanning = true; panStart = { x: e.clientX - transform.x, y: e.clientY - transform.y }; }
      });
      window.addEventListener('mousemove', (e) => {
        if (isPanning) { transform.x = e.clientX - panStart.x; transform.y = e.clientY - panStart.y; draw(); }
      });
      window.addEventListener('mouseup', () => { isPanning = false; });
      selector.addEventListener('change', () => { loadCapture(parseInt(selector.value) || 0); });
    }

    // Initial load — default to capture with most propagators
    const defaultCaptureIndex = ${defaultCapture};
    selector.value = String(defaultCaptureIndex);
    resize();
    window.addEventListener('resize', () => { resize(); draw(); });
    loadCapture(defaultCaptureIndex);
  })();
  </script>
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
