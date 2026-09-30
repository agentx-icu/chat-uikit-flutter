import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What a hardware Enter press asked for, waiting for its `\n` to arrive.
enum HardwareEnterIntent { send, newline }

/// One hardware-Enter send, handed to [HardwareEnterToSend.send].
class HardwareEnterSend {
  HardwareEnterSend(this.text);

  /// The message text, captured when the Enter's newline arrived.
  final String text;

  /// Set when the formatter rebased the field past this text (a key typed
  /// while the platform still echoed it): the text is then no longer in the
  /// composer, so if the send fails the composer must put it back. Otherwise
  /// the text is still in the field (the composer clears it only after a
  /// successful send), exactly like the send button's text.
  bool get removedFromField => _removedFromField;
  bool _removedFromField = false;
}

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

  /// Sends the handle's text — the field's text without the Enter's `\n`,
  /// CAPTURED when that newline arrived. If the send fails after the field
  /// was rebased past it ([HardwareEnterSend.removedFromField]), the caller
  /// puts it back (see [mergeRestored]). Runs in a microtask, after the
  /// formatted value is stored (sending from inside the formatter let a synchronous composer
  /// clear be overwritten by the formatter's own result). It must not re-read
  /// the controller: the text-input channel's handler continues in
  /// microtasks, so the platform's NEXT update (a key typed right after Enter)
  /// is applied before this runs — a controller read sent `abc\nh` (measured
  /// on the iPad simulator).
  final void Function(HardwareEnterSend sent) send;

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

  /// The platform text (with the Enter's `\n`) of the send that was just
  /// made, split at the platform caret, while the platform may still echo it;
  /// see the class doc and [_rebaseAfterSend].
  String? _echoPrefix;
  String _echoSuffix = '';
  HardwareEnterSend? _sent;
  DateTime? _sentAt;

  /// Failed sends the composer put back in front of the field while the
  /// echo was still live ([restoredInFront]); a rebased update keeps them.
  final List<String> _restoredHead = [];

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

  /// Stop treating updates as the echo of the last send (the platform caught
  /// up, the echo expired, or the composer switched conversation).
  void forgetEcho() {
    _echoPrefix = null;
    _echoSuffix = '';
    _sent = null;
    _sentAt = null;
    _restoredHead.clear();
  }

  /// The composer put [texts] (failed sends) back in front of the field
  /// ([mergeRestored]). While the platform may still echo, a stale update
  /// maps to `mergeRestored(texts, <typed since>)` — the value the field now
  /// derives from — instead of dropping them again (after `a` failed and a
  /// queued `b` went out, the platform's `a\nb\nx` must give `a\nx`), and a
  /// genuine edit of the restored text that still starts with the echo's
  /// prefix (`abc\nh` → `abc\nhi`) maps to itself.
  void restoredInFront(List<String> texts) {
    if (_echoPrefix != null) _restoredHead.addAll(texts);
  }

  /// [sent] did not go out: if the platform may still echo it, stop
  /// rebasing — its stale updates hold the text, so they are kept as they
  /// are, and the field can no longer be moved past it.
  void stopEcho(HardwareEnterSend sent) {
    if (identical(_sent, sent)) forgetEcho();
  }

  /// The composer text after putting back failed sends: [texts] (in send
  /// order) in front of what the user has now, one per line.
  static String mergeRestored(Iterable<String> texts, String current) =>
      [...texts, current].where((t) => t.isNotEmpty).join('\n');

  TextEditingValue _format(TextEditingValue oldValue, TextEditingValue value) {
    // Rebase first, then look for the NEXT Enter in what remains: a second
    // quick Enter can arrive while the platform still echoes the first send's
    // text (`abc\nh\n`).
    final platformValue = value;
    final rebased = _rebaseAfterSend(value);
    if (rebased != null) {
      value = rebased;
      // In the rebased coordinates the sent text is gone: while the field
      // still shows it (the composer clears after the send completes), the
      // previous value to compare with is empty.
      if (oldValue.text == _sent?.text) oldValue = TextEditingValue.empty;
      _sent?._removedFromField = true;
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
      // In PLATFORM coordinates: what the platform will keep echoing, split
      // at its caret, where the next key lands (Enter in the middle of a
      // draft: `ab\ncd`, a key gives `ab\nhcd`).
      final platformText = platformValue.text;
      final platformCaret = platformValue.selection.isValid &&
              platformValue.selection.isCollapsed
          ? platformValue.selection.baseOffset.clamp(0, platformText.length)
          : platformText.length;
      _echoPrefix = platformText.substring(0, platformCaret);
      _echoSuffix = platformText.substring(platformCaret);
      // Anything restored in front is part of this message now.
      _restoredHead.clear();
      final sent = _sent = HardwareEnterSend(text);
      _sentAt = _clock();
      scheduleMicrotask(() => send(sent));
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

  /// While the platform still echoes the text that was sent, keep only what
  /// the user typed since: an update that still starts with the echo's prefix
  /// (up to and including the Enter's `\n`) is the echo (`prefix` + `suffix`,
  /// the suffix being what followed the caret — empty unless Enter was
  /// pressed in the middle of the draft) with one edit after the prefix
  /// (`ab\ncd` → `ab\nhcd`, or `ab\nchd` after a quick caret move); the
  /// inserted text is what was typed. The first update that does not start
  /// with the prefix — the platform has caught up — ends this.
  TextEditingValue? _rebaseAfterSend(TextEditingValue value) {
    final prefix = _echoPrefix;
    final sentAt = _sentAt;
    if (prefix == null || sentAt == null) return null;
    final text = value.text;
    if (_clock().difference(sentAt) > maxAge || !text.startsWith(prefix)) {
      forgetEcho();
      return null;
    }
    final base = prefix + _echoSuffix;
    // The edit's span: common suffix first (so an insertion is placed at the
    // caret side), never reaching into the prefix; then the common prefix.
    final limit =
        (text.length < base.length ? text.length : base.length) - prefix.length;
    var tail = 0;
    while (tail < limit &&
        text.codeUnitAt(text.length - 1 - tail) ==
            base.codeUnitAt(base.length - 1 - tail)) {
      tail++;
    }
    var head = prefix.length;
    while (head < text.length - tail &&
        head < base.length - tail &&
        text.codeUnitAt(head) == base.codeUnitAt(head)) {
      head++;
    }
    final typed = text.substring(head, text.length - tail);
    final merged = mergeRestored(_restoredHead, typed);
    final lead = merged.length - typed.length;
    int shift(int offset) => (offset - head).clamp(0, typed.length) + lead;
    final selection = value.selection;
    final composing = value.composing;
    return TextEditingValue(
      text: merged,
      selection: selection.isValid
          ? selection.copyWith(
              baseOffset: shift(selection.baseOffset),
              extentOffset: shift(selection.extentOffset),
            )
          : selection,
      composing: composing.isValid &&
              composing.start >= head &&
              composing.end <= head + typed.length
          ? TextRange(
              start: shift(composing.start),
              end: shift(composing.end),
            )
          : TextRange.empty,
    );
  }

}
