import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What a hardware Enter press asked for, waiting for its `\n` to arrive.
enum HardwareEnterIntent { send, newline }

/// Hardware-keyboard Enter for the MOBILE composer (iPad / Android tablets):
/// plain Enter sends, Enter with a modifier inserts a newline.
///
/// WHY NOT DECIDE IN THE KEY HANDLER. The key event reaches the framework before
/// the characters typed just ahead of it: on iOS the engine hands an unhandled
/// press to UIKit, which inserts the text later through its keyboard task queue,
/// so the resulting editing-state update lands after the NEXT press (Enter) was
/// already handled. Sending from the key handler read a stale field — typing
/// `qwerty` and Enter without a pause sent `qwe`, after which UIKit's pending
/// characters re-filled the composer — and a newline written into the
/// controller from the key handler was overwritten by UIKit's later state
/// (`abc` Shift+Enter `def` came out as `abcdef`).
///
/// So the Enter is left to the platform, which inserts `\n` into the multiline
/// field IN ORDER after the pending characters (iOS: UIKit `insertText:`;
/// Android: `InputConnectionAdaptor.handleKeyEvent` commits `getUnicodeChar()`),
/// and the intent recorded at key-down is applied when that `\n` shows up in the
/// editing stream ([formatter]): a send strips it and sends the now-complete
/// text, a newline keeps it. Intents queue up, one per Enter, so presses that
/// all land before their newlines (Shift+Enter then Enter) are applied in order.
///
/// The same lag applies after the send: the platform still holds the text WITH
/// the Enter's `\n` until it processes the framework's stripped/cleared value,
/// so a key typed right after Enter comes back as `<sent text>\n<key>`
/// (measured: `abc` Enter `h` left `abc\nh` in the composer, which the next
/// Enter sent). While that stale base is still echoed, updates are rebased
/// onto what follows it.
///
/// Only modifiers the platform turns into a newline take that path, or the
/// queued intent would wait for a `\n` that never comes and pair up with the
/// next Enter's. Measured on the iPad simulator (iOS 18.4): UIKit inserts it for
/// Shift+Return and Option+Return, not for Command+Return or Control+Return.
/// Android commits `getUnicodeChar()`, which is 0 under Ctrl/Alt/Meta. Those
/// combinations keep the framework-side insertion ([handleKeyEvent]'s
/// `insertNewline`), with its lag; Shift+Enter, the common one, is ordered on
/// both.
class HardwareEnterToSend {
  HardwareEnterToSend({
    required this.canSend,
    required this.send,
    bool? platformInsertsAltNewline,
    DateTime Function()? clock,
    this.maxAge = const Duration(seconds: 1),
  })  : platformInsertsAltNewline = platformInsertsAltNewline ??
            defaultTargetPlatform == TargetPlatform.iOS,
        _clock = clock ?? DateTime.now;

  /// Whether [send] will send [text] (non-empty, within the byte limit). Asked
  /// synchronously so the post-send rebase is only armed for a send that will
  /// happen; [send] must therefore not drop an accepted text (e.g. it waits for
  /// a send already in flight instead of refusing).
  final bool Function(String text) canSend;

  /// Sends [text] — the field's text without the Enter's `\n`, CAPTURED when
  /// that newline arrived. (If that send then fails after the user already
  /// typed past it, the text is not put back into the field: restoring it
  /// raced later queued sends and the draft; the button path's behaviour —
  /// the text stays while it is unchanged — holds when nothing was typed.) Runs in a microtask, after the formatted value is
  /// stored (sending from inside the formatter let a synchronous composer
  /// clear be overwritten by the formatter's own result). It must not re-read
  /// the controller: the text-input channel's handler continues in
  /// microtasks, so the platform's NEXT update (a key typed right after Enter)
  /// is applied before this runs — a controller read sent `abc\nh` (measured
  /// on the iPad simulator).
  final void Function(String text) send;

  /// Alt(Option)+Enter is inserted by the platform (iOS) rather than by the
  /// framework (Android).
  final bool platformInsertsAltNewline;

  /// How long a recorded intent waits for its `\n`. The platform inserts it
  /// within a frame or two; the bound only keeps an Enter the platform never
  /// turned into text (e.g. an IME that consumed it) from hijacking a later,
  /// unrelated newline.
  final Duration maxAge;

  final DateTime Function() _clock;
  final Queue<(HardwareEnterIntent, DateTime)> _pending = Queue();

  /// Platform text (with the Enter's `\n`) that was just sent, while the
  /// platform may still echo it; see the class doc.
  String? _sentBase;
  String? _sentText;
  DateTime? _sentAt;

  late final TextInputFormatter formatter =
      TextInputFormatter.withFunction(_format);

  @visibleForTesting
  List<HardwareEnterIntent> get pendingIntents =>
      [for (final (intent, _) in _pending) intent];

  /// `Focus.onKeyEvent` handler for the composer.
  ///
  /// [composing]: the field has an active IME composition (the Enter confirms
  /// it, so it is the IME's). [insertNewline] writes a newline at the caret.
  KeyEventResult handleKeyEvent(
    KeyEvent event, {
    required bool composing,
    required VoidCallback insertNewline,
  }) {
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    // Other keys do NOT clear pending intents: a key typed right after Enter
    // can reach the framework before the Enter's own `\n` does (same queue lag
    // as above), and clearing then would turn the send into a stray newline.
    if (event is! KeyDownEvent || !isEnter || composing) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        (keyboard.isAltPressed && !platformInsertsAltNewline)) {
      insertNewline();
      return KeyEventResult.handled;
    }
    _dropExpired();
    _pending.add((
      keyboard.isShiftPressed || keyboard.isAltPressed
          ? HardwareEnterIntent.newline
          : HardwareEnterIntent.send,
      _clock(),
    ));
    return KeyEventResult.ignored;
  }

  void _dropExpired() {
    final now = _clock();
    while (_pending.isNotEmpty &&
        now.difference(_pending.first.$2) > maxAge) {
      _pending.removeFirst();
    }
  }

  TextEditingValue _format(TextEditingValue oldValue, TextEditingValue value) {
    // Rebase first, then look for the NEXT Enter in what remains: a second
    // quick Enter can arrive while the platform still echoes the first send's
    // text (`abc\nh\n`).
    final platformText = value.text;
    final rebased = _rebaseAfterSend(value);
    if (rebased != null) {
      value = rebased;
      // In the rebased coordinates the sent text is gone: while the field
      // still shows it (the composer clears after the send completes), the
      // previous value to compare with is empty.
      if (oldValue.text == _sentText) oldValue = TextEditingValue.empty;
    }
    _dropExpired();
    if (_pending.isEmpty || !_insertedNewlineAtCaret(oldValue, value)) {
      // Characters that were still in flight arrive in earlier updates: they
      // pass through untouched and the intent stays queued.
      return value;
    }
    final (intent, _) = _pending.removeFirst();
    if (intent == HardwareEnterIntent.newline) return value;
    // Enter over a selection (e.g. after Cmd+A): the platform replaced the
    // selected text with its `\n`. A send means the whole draft as the user
    // saw it, not what is left after the replacement — stripping the newline
    // there erased the selected draft.
    final oldSelection = oldValue.selection;
    final overSelection = oldSelection.isValid && !oldSelection.isCollapsed;
    final caret = value.selection.baseOffset;
    final text = overSelection
        ? oldValue.text
        : value.text.replaceRange(caret - 1, caret, '');
    if (canSend(text)) {
      // In PLATFORM coordinates: what the platform will keep echoing.
      _sentBase = platformText;
      _sentText = text;
      _sentAt = _clock();
      scheduleMicrotask(() => send(text));
    }
    if (overSelection) return oldValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret - 1),
    );
  }

  /// Whether this update is an Enter's newline: the character just before the
  /// new collapsed caret is `\n`, the text after the caret is unchanged (a
  /// suffix of the old text), and the edit added a newline or inserted
  /// something (it is not a deletion that happens to leave a `\n` before the
  /// caret). Covers inserting before an existing newline, replacing a
  /// selection that contained one, and an autocorrect rewriting the last word
  /// in the same update.
  static bool _insertedNewlineAtCaret(
    TextEditingValue oldValue,
    TextEditingValue value,
  ) {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return false;
    final caret = selection.baseOffset;
    final text = value.text;
    if (caret <= 0 || caret > text.length) return false;
    if (text.codeUnitAt(caret - 1) != 0x0A) return false;
    if (!oldValue.text.endsWith(text.substring(caret))) return false;
    // One more newline than before (also when an autocorrect shortened the
    // word in the same update: `helllo` -> `hello\n`), or — replacing a
    // selection that held a newline keeps the count — a net insertion.
    if (_newlines(text) > _newlines(oldValue.text)) return true;
    final oldSelection = oldValue.selection;
    final replaced =
        oldSelection.isValid ? oldSelection.end - oldSelection.start : 0;
    return text.length >= oldValue.text.length - replaced + 1;
  }

  static int _newlines(String text) => '\n'.allMatches(text).length;

  /// While the platform still echoes the text that was sent (plus whatever
  /// was typed after the Enter), keep only what follows it. The first update
  /// that no longer starts with it — the platform has caught up — ends this.
  TextEditingValue? _rebaseAfterSend(TextEditingValue value) {
    final base = _sentBase;
    final sentAt = _sentAt;
    if (base == null || sentAt == null) return null;
    if (_clock().difference(sentAt) > maxAge || !value.text.startsWith(base)) {
      _sentBase = null;
      _sentText = null;
      _sentAt = null;
      return null;
    }
    int shift(int offset) => (offset - base.length).clamp(0, 1 << 30);
    final selection = value.selection;
    final composing = value.composing;
    return TextEditingValue(
      text: value.text.substring(base.length),
      selection: selection.isValid
          ? selection.copyWith(
              baseOffset: shift(selection.baseOffset),
              extentOffset: shift(selection.extentOffset),
            )
          : selection,
      composing: composing.isValid && composing.start >= base.length
          ? TextRange(
              start: shift(composing.start),
              end: shift(composing.end),
            )
          : TextRange.empty,
    );
  }
}
