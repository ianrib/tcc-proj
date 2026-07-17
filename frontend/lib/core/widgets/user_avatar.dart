import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_avatar_provider.dart';
import '../providers/user_provider.dart';
import '../utils/string_utils.dart';

class UserAvatar extends ConsumerStatefulWidget {
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.radius,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  @override
  void initState() {
    super.initState();
    _triggerLoad();
  }

  void _triggerLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(userAvatarProvider.notifier).loadAvatar(user.uid);
        if (user.photoURL != null) {
          ref.read(userAvatarProvider.notifier).fetchAndCacheAvatar(user.uid, user.photoURL!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? theme.colorScheme.secondary,
        child: Icon(
          Icons.person,
          size: widget.radius,
          color: widget.textColor ?? Colors.white,
        ),
      );
    }

    final displayNameRaw = user.displayName ?? (user.email != null ? user.email!.split('@').first : 'Usuário');
    final displayName = StringUtils.formatDisplayName(displayNameRaw);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final photoUrl = user.photoURL;

    // Trigger load when the user updates or switches
    final avatars = ref.watch(userAvatarProvider);
    if (!avatars.containsKey(user.uid)) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(userAvatarProvider.notifier).loadAvatar(user.uid);
        if (photoUrl != null) {
          ref.read(userAvatarProvider.notifier).fetchAndCacheAvatar(user.uid, photoUrl);
        }
      });
    }

    if (photoUrl == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? theme.colorScheme.secondary,
        child: Text(
          initial,
          style: TextStyle(
            color: widget.textColor ?? Colors.white,
            fontSize: widget.fontSize ?? (widget.radius * 0.8),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final cachedBase64 = avatars[user.uid];
    if (cachedBase64 != null) {
      try {
        final bytes = base64Decode(cachedBase64);
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: MemoryImage(bytes),
          backgroundColor: widget.backgroundColor ?? theme.colorScheme.secondary,
        );
      } catch (e) {
        // Fallback to NetworkImage if base64 decoding fails
      }
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: NetworkImage(photoUrl),
      backgroundColor: widget.backgroundColor ?? theme.colorScheme.secondary,
      child: Text(
        initial,
        style: TextStyle(
          color: widget.textColor ?? Colors.white,
          fontSize: widget.fontSize ?? (widget.radius * 0.8),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
