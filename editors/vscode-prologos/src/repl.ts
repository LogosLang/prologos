import * as vscode from 'vscode';
import { LanguageClient } from 'vscode-languageclient/node';
import { getTopLevelFormRange, getExpressionText } from './forms';
import { DecorationsManager } from './decorations';

interface EvalResult {
  text: string;
  isError: boolean;
}

interface EvalResponse {
  results: EvalResult[];
}

interface TypeOfResponse {
  type: string;
}

/**
 * Manages the Prologos REPL: sends eval requests to the LSP server,
 * displays results inline, and logs to the output channel.
 */
export class ReplManager {
  private client: LanguageClient;
  private channel: vscode.OutputChannel;
  private decorations: DecorationsManager;

  constructor(
    client: LanguageClient,
    channel: vscode.OutputChannel,
    decorations: DecorationsManager
  ) {
    this.client = client;
    this.channel = channel;
    this.decorations = decorations;
  }

  /**
   * Evaluate the top-level form at the cursor.
   */
  async evalTopLevel(): Promise<void> {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') return;

    const range = getTopLevelFormRange(editor.document, editor.selection.active);
    if (!range) {
      vscode.window.showWarningMessage('No form found at cursor');
      return;
    }

    const code = editor.document.getText(range);
    await this.evalAndDisplay(editor, range, code);
  }

  /**
   * Evaluate the current selection, or the expression at cursor.
   */
  async evalSelection(): Promise<void> {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') return;

    const expr = getExpressionText(editor);
    if (!expr) {
      vscode.window.showWarningMessage('No expression found');
      return;
    }

    await this.evalAndDisplay(editor, expr.range, expr.text);
  }

  /**
   * Load the entire file into the REPL session.
   */
  async loadFile(): Promise<void> {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') return;

    const uri = editor.document.uri.toString();
    const code = editor.document.getText();

    this.channel.appendLine(`> [Load file: ${editor.document.fileName}]`);

    try {
      const response = await this.client.sendRequest<EvalResponse>(
        '$/prologos/loadFile',
        { uri, code }
      );

      const errors = response.results.filter(r => r.isError);
      const successes = response.results.filter(r => !r.isError);

      for (const r of response.results) {
        this.channel.appendLine(r.isError ? `ERROR: ${r.text}` : r.text);
      }

      const msg = `Loaded: ${successes.length} results, ${errors.length} errors`;
      this.channel.appendLine(msg);
      this.channel.appendLine('');

      if (errors.length > 0) {
        vscode.window.showWarningMessage(`Prologos: ${msg}`);
      } else {
        vscode.window.showInformationMessage(`Prologos: ${msg}`);
      }
    } catch (err: any) {
      this.channel.appendLine(`ERROR: ${err.message}`);
      vscode.window.showErrorMessage(`Prologos eval failed: ${err.message}`);
    }
  }

  /**
   * Show the type of the expression at cursor.
   */
  async typeOf(): Promise<void> {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') return;

    const expr = getExpressionText(editor);
    if (!expr) {
      vscode.window.showWarningMessage('No expression found');
      return;
    }

    const uri = editor.document.uri.toString();

    try {
      const response = await this.client.sendRequest<TypeOfResponse>(
        '$/prologos/typeOf',
        { uri, code: expr.text.trim() }
      );

      const typeStr = response.type || 'unknown';
      this.decorations.showResult(editor, expr.range, typeStr, false);
      this.channel.appendLine(`> :type ${expr.text.trim()}`);
      this.channel.appendLine(typeStr);
      this.channel.appendLine('');
    } catch (err: any) {
      vscode.window.showErrorMessage(`Type inference failed: ${err.message}`);
    }
  }

  /**
   * Reset the REPL session for the current file.
   */
  async resetSession(): Promise<void> {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'prologos') return;

    const uri = editor.document.uri.toString();

    try {
      await this.client.sendRequest('$/prologos/resetSession', { uri });
      this.decorations.clearForUri(uri);
      this.channel.appendLine('--- Session reset ---');
      this.channel.appendLine('');
      vscode.window.showInformationMessage('Prologos: REPL session reset');
    } catch (err: any) {
      vscode.window.showErrorMessage(`Reset failed: ${err.message}`);
    }
  }

  /**
   * Core eval: send code to server, display results inline and in channel.
   */
  private async evalAndDisplay(
    editor: vscode.TextEditor,
    range: vscode.Range,
    code: string
  ): Promise<void> {
    const uri = editor.document.uri.toString();
    const trimmed = code.trim();

    // Log to REPL channel
    this.channel.appendLine(`> ${trimmed.split('\n')[0]}${trimmed.includes('\n') ? ' ...' : ''}`);

    try {
      const response = await this.client.sendRequest<EvalResponse>(
        '$/prologos/eval',
        { uri, code }
      );

      if (response.results.length === 0) {
        this.channel.appendLine('(no result)');
        this.channel.appendLine('');
        return;
      }

      // Show the last result inline (most relevant for multi-form evals)
      const lastResult = response.results[response.results.length - 1];
      this.decorations.showResult(editor, range, lastResult.text, lastResult.isError);

      // Log all results
      for (const r of response.results) {
        this.channel.appendLine(r.isError ? `ERROR: ${r.text}` : r.text);
      }
      this.channel.appendLine('');
    } catch (err: any) {
      this.decorations.showResult(editor, range, err.message, true);
      this.channel.appendLine(`ERROR: ${err.message}`);
      this.channel.appendLine('');
    }
  }
}
