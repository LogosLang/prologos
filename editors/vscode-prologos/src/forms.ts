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
  while (startLine > 0) {
    const prevLine = document.lineAt(startLine - 1);
    const prevText = prevLine.text;
    // If previous line is blank or indented, it belongs to an earlier form or is a separator
    if (prevText.trim() === '') {
      // Blank line: check if it's within a form (has non-blank col-0 line above and below)
      // Walk further up to see
      let checkLine = startLine - 2;
      while (checkLine >= 0 && document.lineAt(checkLine).text.trim() === '') {
        checkLine--;
      }
      if (checkLine >= 0 && !isTopLevelStart(document.lineAt(checkLine).text)) {
        startLine = checkLine + 1;
        continue;
      }
      break;
    }
    if (isTopLevelStart(prevText)) {
      // Previous line starts a different top-level form — if current line also starts
      // at col 0, we've found our boundary
      if (isTopLevelStart(document.lineAt(startLine).text)) {
        break; // startLine is already the start of our form
      }
      // Otherwise, cursor is in the continuation of the prev line's form
      startLine = startLine - 1;
    } else {
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
      if (nextNonBlank < lineCount && !isTopLevelStart(document.lineAt(nextNonBlank).text)) {
        // Next non-blank line is indented — blank line is within the form
        endLine = i;
        continue;
      }
      // Blank followed by col-0 or EOF — form ends here
      break;
    }
    if (isTopLevelStart(lineText)) {
      // New top-level form starts — our form ended on the previous line
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
