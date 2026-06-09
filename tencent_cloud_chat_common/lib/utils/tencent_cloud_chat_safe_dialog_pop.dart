import 'package:flutter/widgets.dart';

/// Pop the route that owns [context] with [result], but ONLY while that route is
/// still the topmost (current) one.
///
/// A dialog/sheet button's `onPressed` can fire TWICE in quick succession — a
/// real fast double-click, or a test harness (flutter_skill) that dispatches a
/// synthetic pointer AND directly invokes `onPressed`. An unguarded
/// `Navigator.pop` then runs twice: the first closes the dialog, the second —
/// invoked while the button is still mounted mid-dismiss — unwinds the PAGE
/// underneath, emptying the Navigator and blanking the whole window.
/// `ModalRoute.isCurrent` flips to false synchronously inside the first
/// `Navigator.pop`, so the guarded second call is a no-op.
///
/// Use this for dialog/bottom-sheet buttons whose callback uses the
/// dialog/sheet BUILDER context (the `(ctx) =>` of showDialog /
/// showModalBottomSheet / showCupertinoModalPopup). For dialogs whose actions
/// capture an OUTER/State context instead (e.g. a prebuilt `actions:` list
/// handed to `showAdaptiveDialog`), this would test the wrong route and wrongly
/// suppress the pop — guard those with a one-shot flag at the call site instead.
///
/// This is the fork-local twin of toxee's `lib/ui/widgets/safe_dialog_pop.dart`
/// (the fork cannot import the app). Single-tap behaviour is unchanged.
void popDialogIfCurrent<T>(BuildContext context, [T? result]) {
  final route = ModalRoute.of(context);
  if (route != null && route.isCurrent) {
    Navigator.of(context).pop(result);
  }
}
