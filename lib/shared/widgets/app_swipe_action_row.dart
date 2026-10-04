import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Directional, reveal-only Edit/Delete row extracted from Recurring.
class AppSwipeActionRow extends StatefulWidget {
  const AppSwipeActionRow({
    super.key,
    required this.child,
    required this.isOpen,
    required this.onOpenRequested,
    required this.onCloseRequested,
    required this.onInteractionStart,
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.editActionKey,
    required this.deleteActionKey,
    required this.deleteLabel,
    this.onForegroundTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final bool isOpen;
  final VoidCallback onOpenRequested;
  final VoidCallback onCloseRequested;

  /// Recurring History Final Corrections checkpoint: called when the
  /// foreground content is tapped WHILE THE ROW IS CLOSED
  /// (`_dragExtent == 0`) -- i.e. an ordinary, non-swipe tap on the
  /// row's own content, never a drag. `null` by default (opt-in,
  /// pixel/behavior-identical to every call site that doesn't pass it).
  ///
  /// Deliberately NOT called when the row is open -- see
  /// [AppSwipeActionRowState._handleTap]: a tap while open only closes
  /// the reveal panel, exactly as before this field existed. This is
  /// what makes "tap an open row's foreground" close-only (never also
  /// navigate) and "tap a closed row's foreground" navigate-only
  /// (never fight with the close behavior), per this checkpoint's
  /// explicit two-branch contract:
  /// ```
  /// if row is currently open:
  ///     tap foreground -> close reveal only
  /// else:
  ///     tap ordinary foreground content -> navigate to service history
  /// ```
  ///
  /// Never fires for a tap that a descendant Material widget (Post,
  /// Skip, the overflow `IconButton`, or either reveal action) already
  /// claimed -- `onTap` here only fires for whichever recognizer wins
  /// this pointer's gesture arena, and those widgets' own `InkWell`-
  /// based recognizers reliably win their own bounded area over this
  /// ambient one (see this class's own "Interaction, not just paint
  /// order" doc section, and the proven precedent the removed
  /// `recurringRowHistory_` `IconButton` already established for Post/
  /// Skip/overflow coexisting safely with this same ambient detector).
  final VoidCallback? onForegroundTap;

  /// Called the instant a pointer-down interaction begins anywhere on
  /// this row -- including plain, non-swipe content, and regardless of
  /// whether this specific `GestureDetector`'s tap or drag recognizer
  /// ends up "winning" this pointer's gesture arena. The parent
  /// (`_RecurringRuleListBodyState._handleRowInteractionStart`) uses
  /// this purely to close whichever OTHER row is currently open; it
  /// never opens or closes THIS row (that stays [onOpenRequested]/
  /// [onCloseRequested]'s job exclusively). See the call site below
  /// (`onTapDown`) for why `onTapDown` specifically, not `onTap`, is
  /// what makes this reliable.
  final VoidCallback onInteractionStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final Key editActionKey;
  final Key deleteActionKey;
  final String deleteLabel;

  /// Applied as the outermost `Padding` around the whole swipe stack --
  /// see the class doc's "Closed-state bleed fix" section for why this
  /// must never be applied to [child] (the foreground `AppCard`) alone.
  final EdgeInsetsGeometry margin;

  static const double revealWidth = 144;

  @override
  State<AppSwipeActionRow> createState() => AppSwipeActionRowState();
}

class AppSwipeActionRowState extends State<AppSwipeActionRow> {
  double _dragExtent = 0;
  bool _dragging = false;

  /// The settled extent (`-revealWidth`, `0`, or `+revealWidth`) this
  /// row was last opened to -- positive means the Edit panel (left),
  /// negative means the Delete panel (right), matching [_dragExtent]'s
  /// own sign convention exactly. Tracked separately from [_dragExtent]
  /// purely so [didUpdateWidget] can re-snap to the correct SIDE (not
  /// just "any" open side) if the parent re-confirms [isOpen] after an
  /// unrelated rebuild -- `0` would otherwise be ambiguous with "never
  /// opened yet".
  double _openExtent = 0;

  @override
  void didUpdateWidget(AppSwipeActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging) return;
    final double target = widget.isOpen ? _openExtent : 0;
    if (_dragExtent != target) setState(() => _dragExtent = target);
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx)
          .clamp(-AppSwipeActionRow.revealWidth, AppSwipeActionRow.revealWidth);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    const double half = AppSwipeActionRow.revealWidth / 2;
    final double settled = _dragExtent <= -half
        ? -AppSwipeActionRow.revealWidth
        : _dragExtent >= half
            ? AppSwipeActionRow.revealWidth
            : 0;
    setState(() {
      _dragExtent = settled;
      _openExtent = settled;
    });
    if (settled == 0) {
      widget.onCloseRequested();
    } else {
      widget.onOpenRequested();
    }
  }

  void _handleTap() {
    if (_dragExtent != 0) {
      widget.onCloseRequested();
    } else {
      // Closed-row ordinary tap -- see [AppSwipeActionRow.onForegroundTap]'s
      // own doc comment for the full "why" of this two-branch contract.
      widget.onForegroundTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(context.appTokens.radii.medium);

    return Padding(
      padding: widget.margin,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: AppSwipeActionRow.revealWidth,
              // Unreachable unless the Edit side is at least partly
              // dragged open -- see the class doc's "Interaction, not
              // just paint order" section.
              child: IgnorePointer(
                ignoring: _dragExtent <= 0,
                child: _RevealActionButton(
                  key: widget.editActionKey,
                  icon: Icons.edit_outlined,
                  label: widget.editLabel,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  onPressed: () {
                    widget.onCloseRequested();
                    widget.onEdit();
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: AppSwipeActionRow.revealWidth,
              // Unreachable unless the Delete side is at least partly
              // dragged open -- same reasoning as the Edit panel above.
              child: IgnorePointer(
                ignoring: _dragExtent >= 0,
                child: _RevealActionButton(
                  key: widget.deleteActionKey,
                  icon: Icons.delete_outline,
                  label: widget.deleteLabel,
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  onPressed: () {
                    widget.onCloseRequested();
                    widget.onDelete();
                  },
                ),
              ),
            ),
            GestureDetector(
              // `onTapDown` (NOT `onTap`) is the cross-row-tap fix:
              // it fires on EVERY `GestureDetector` that is still a
              // candidate at pointer-DOWN time, before Flutter's
              // gesture arena resolves a single winner for this
              // pointer -- unlike `onTap`, which only fires for
              // whichever recognizer ultimately wins. The list body's
              // own ancestor `GestureDetector.onTap` ("tap anywhere
              // closes the open row") and this row's `onTap` compete
              // in that SAME arena, and the ancestor's `onTap` can
              // lose, silently never closing another open row. Firing
              // `widget.onInteractionStart()` here reaches the parent
              // unconditionally, regardless of who wins -- see that
              // callback's own doc comment.
              onTapDown: (_) => widget.onInteractionStart(),
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_dragExtent, 0, 0),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealActionButton extends StatelessWidget {
  const _RevealActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 72,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: foregroundColor),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: foregroundColor, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

