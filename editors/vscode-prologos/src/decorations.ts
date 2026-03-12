import * as vscode from 'vscode';

/**
 * Manages inline result decorations for the Prologos REPL.
 * Results appear as grey italic text after the last line of the evaluated form.
 * Errors appear in red.
 */

const resultDecorationType = vscode.window.createTextEditorDecorationType({
  isWholeLine: false,
});

const errorDecorationType = vscode.window.createTextEditorDecorationType({
  isWholeLine: false,
});

interface DecorationEntry {
  range: vscode.Range;
  text: string;
  isError: boolean;
}

export class DecorationsManager {
  // Active decorations per URI
  private decorations: Map<string, DecorationEntry[]> = new Map();
  private disposables: vscode.Disposable[] = [];

  constructor() {
    // Clear decorations when document changes
    this.disposables.push(
      vscode.workspace.onDidChangeTextDocument((e) => {
        this.clearForUri(e.document.uri.toString());
      })
    );
  }

  /**
   * Show an inline result on the last line of the given range.
   */
  showResult(editor: vscode.TextEditor, range: vscode.Range, text: string, isError: boolean): void {
    const uri = editor.document.uri.toString();
    let entries = this.decorations.get(uri) || [];

    // Remove any existing decoration that overlaps this range
    entries = entries.filter(e => !e.range.intersection(range));

    entries.push({ range, text, isError });
    this.decorations.set(uri, entries);
    this.applyDecorations(editor);
  }

  /**
   * Clear all decorations for a URI.
   */
  clearForUri(uri: string): void {
    this.decorations.delete(uri);
    // Apply to all visible editors for this URI
    for (const editor of vscode.window.visibleTextEditors) {
      if (editor.document.uri.toString() === uri) {
        editor.setDecorations(resultDecorationType, []);
        editor.setDecorations(errorDecorationType, []);
      }
    }
  }

  /**
   * Clear all decorations everywhere.
   */
  clearAll(): void {
    this.decorations.clear();
    for (const editor of vscode.window.visibleTextEditors) {
      editor.setDecorations(resultDecorationType, []);
      editor.setDecorations(errorDecorationType, []);
    }
  }

  /**
   * Apply all decorations to the given editor.
   */
  private applyDecorations(editor: vscode.TextEditor): void {
    const uri = editor.document.uri.toString();
    const entries = this.decorations.get(uri) || [];

    const resultDecorations: vscode.DecorationOptions[] = [];
    const errorDecorations: vscode.DecorationOptions[] = [];

    for (const entry of entries) {
      const lastLine = entry.range.end.line;
      const lineLen = editor.document.lineAt(lastLine).text.length;
      const decorRange = new vscode.Range(lastLine, lineLen, lastLine, lineLen);

      // Truncate long results for inline display
      const displayText = entry.text.length > 80
        ? entry.text.substring(0, 77) + '...'
        : entry.text;

      const opts: vscode.DecorationOptions = {
        range: decorRange,
        renderOptions: {
          after: {
            contentText: `  => ${displayText}`,
            color: entry.isError
              ? new vscode.ThemeColor('errorForeground')
              : new vscode.ThemeColor('editorCodeLens.foreground'),
            fontStyle: 'italic',
            margin: '0 0 0 1em',
          },
        },
      };

      if (entry.isError) {
        errorDecorations.push(opts);
      } else {
        resultDecorations.push(opts);
      }
    }

    editor.setDecorations(resultDecorationType, resultDecorations);
    editor.setDecorations(errorDecorationType, errorDecorations);
  }

  dispose(): void {
    for (const d of this.disposables) {
      d.dispose();
    }
    resultDecorationType.dispose();
    errorDecorationType.dispose();
  }
}
