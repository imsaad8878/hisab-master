import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// CircleAvatar that shows: custom uploaded photo > Google photo > initials/icon.
Widget userAvatar(AppUser? user, {double radius = 20}) {
  if (user?.photoBase64 != null && user!.photoBase64!.isNotEmpty) {
    try {
      final bytes = base64Decode(user.photoBase64!);
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
      );
    } catch (_) {
      // fall through
    }
  }
  if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(user.photoURL!));
  }
  final name = user?.displayName?.trim();
  final initial = name != null && name.isNotEmpty ? name[0].toUpperCase() : null;
  if (initial != null) {
    return CircleAvatar(radius: radius, child: Text(initial));
  }
  return CircleAvatar(
    radius: radius,
    child: const Icon(Icons.person, size: 20),
  );
}
