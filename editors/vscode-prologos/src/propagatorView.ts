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
  private extensionPath: string;

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
    const d3Uri = this.getD3Uri();
    const net = trace.finalNetwork;
    const stats = net.stats;
    const rounds = trace.rounds;

    // Serialize trace data for the webview script
    const traceDataJson = JSON.stringify(trace).replace(/</g, '\\u003c');

    // Build the tabular fallback rows
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
        <span class="legend-swatch" style="background:#6a9955;"></span> Cell (solved)
      </div>
      <div class="legend-item">
        <span class="legend-swatch" style="background:#666;"></span> Cell (unsolved)
      </div>
      <div class="legend-item">
        <span class="legend-swatch" style="background:#f44;"></span> Cell (contradiction)
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
      const node = {
        id: 'c' + c.id,
        type: 'cell',
        cellId: c.id,
        label: '#' + c.id,
        value: c.value,
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
    const H_SPACING = 100;
    const V_SPACING = 70;
    const PADDING = 60;

    // Assign positions
    let maxNodesInLayer = 0;
    Object.values(layerNodes).forEach((arr) => {
      if (arr.length > maxNodesInLayer) maxNodesInLayer = arr.length;
    });

    for (let l = 0; l < numLayers; l++) {
      const layerArr = layerNodes[l] || [];
      const layerWidth = (layerArr.length - 1) * H_SPACING;
      const startX = -layerWidth / 2;
      layerArr.forEach((n, i) => {
        n.x = startX + i * H_SPACING;
        n.y = l * V_SPACING;
      });
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

    // Colors
    const COLORS = {
      cellSolved: '#6a9955',
      cellUnsolved: '#666',
      cellContra: '#f44',
      propagator: '#569cd6',
      edge: '#555',
      edgeHighlight: '#ddd',
      text: getComputedStyle(document.body).color || '#ccc',
      textDim: '#999',
    };

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
          // Circle
          let fill = COLORS.cellUnsolved;
          if (n.contradiction) fill = COLORS.cellContra;
          else if (n.solved) fill = COLORS.cellSolved;

          ctx.beginPath();
          ctx.arc(sx, sy, r, 0, Math.PI * 2);
          ctx.fillStyle = fill;
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
          ctx.fillStyle = COLORS.text;
          ctx.font = Math.max(9, 11 * transform.k) + 'px ' +
            (getComputedStyle(document.body).fontFamily || 'sans-serif');
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillText(n.label, sx, sy);
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
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
