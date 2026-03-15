import * as vscode from 'vscode';

/**
 * Detect the top-level form at the cursor position.
 *
 * Prologos WS-mode convention: top-level forms start at column 0.
 * Indented lines (and blank lines within) belong to the form above.
 * A new top-level form starts at the next non-blank, non-comment line at col 0.
 */
export function getTopLevelFormRange(
  document: vscode.TextDocument,
  position: vscode.Position
): vscode.Range | null {
  const lineCount = document.lineCount;
  if (lineCount === 0) return null;

  // Walk UP from cursor to find the start of the top-level form
  let startLine = position.line;

  // If the cursor line starts at col 0, it IS the start of its own form —
  // no need to walk up. We only walk up when cursor is on an indented line
  // (continuation of a multi-line form like defn body).
  if (!isTopLevelStart(document.lineAt(startLine).text)) {
    while (startLine > 0) {
      const prevLine = document.lineAt(startLine - 1);
      const prevText = prevLine.text;
      if (prevText.trim() === '') {
        // Blank line above an indented line — keep walking up, the form start is higher
        startLine = startLine - 1;
        continue;
      }
      if (isTopLevelStart(prevText)) {
        // Found the col-0 line that starts this form
        startLine = startLine - 1;
        break;
      }
      // Indented or comment-only — belongs to the form, keep going up
      startLine = startLine - 1;
    }
  }

  // Walk DOWN from startLine to find the end of the form
  let endLine = startLine;
  for (let i = startLine + 1; i < lineCount; i++) {
    const lineText = document.lineAt(i).text;
    if (lineText.trim() === '') {
      // Blank line: could be within a form or a separator
      // Peek ahead to see if there's more indented content
      let nextNonBlank = i + 1;
      while (nextNonBlank < lineCount && document.lineAt(nextNonBlank).text.trim() === '') {
        nextNonBlank++;
      }
      if (nextNonBlank < lineCount && isContinuationLine(document.lineAt(nextNonBlank).text)) {
        // Next non-blank line is indented — blank line is within the form
        endLine = i;
        continue;
      }
      // Blank followed by col-0 content, comment, or EOF — form ends here
      break;
    }
    if (!isContinuationLine(lineText)) {
      // New top-level form or comment at col 0 — our form ended on the previous line
      break;
    }
    // Indented line — belongs to current form
    endLine = i;
  }

  // Trim trailing blank lines
  while (endLine > startLine && document.lineAt(endLine).text.trim() === '') {
    endLine--;
  }

  const endLineText = document.lineAt(endLine).text;
  return new vscode.Range(startLine, 0, endLine, endLineText.length);
}

/**
 * Check if a line starts a new top-level form (starts at column 0, not blank, not comment-only).
 */
function isTopLevelStart(text: string): boolean {
  if (text.trim() === '') return false;
  if (text.match(/^\s/)) return false; // starts with whitespace = indented
  if (text.match(/^\s*;/)) return false; // comment-only line
  return true;
}

/**
 * Check if a line is a continuation of the current form (indented content).
 * Returns false for blank lines, col-0 code, and col-0 comments.
 * Col-0 comments are form boundaries — they don't belong to the preceding form.
 */
function isContinuationLine(text: string): boolean {
  if (text.trim() === '') return false;
  if (text.match(/^\s/)) return true; // starts with whitespace = indented = continuation
  return false; // col-0 anything (code or comment) = not continuation
}

/**
 * Get the expression text to evaluate.
 * If there's a selection, use it. Otherwise, get the top-level form.
 */
export function getExpressionText(
  editor: vscode.TextEditor
): { text: string; range: vscode.Range } | null {
  const selection = editor.selection;
  if (!selection.isEmpty) {
    return {
      text: editor.document.getText(selection),
      range: selection,
    };
  }

  const range = getTopLevelFormRange(editor.document, selection.active);
  if (!range) return null;

  return {
    text: editor.document.getText(range),
    range,
  };
}
