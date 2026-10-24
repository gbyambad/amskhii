import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Shows a spinner while loading, a message on error, else [builder].
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return builder(context, value.requireValue);
    if (value.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Өгөгдөл ачаалж чадсангүй. Дахин оролдоно уу.', textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}

/// Pairs two async values: data once both have data, else the first error or loading.
AsyncValue<(A, B)> combineAsync<A, B>(AsyncValue<A> a, AsyncValue<B> b) {
  if (a.hasValue && b.hasValue) return AsyncData((a.requireValue, b.requireValue));
  if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  if (b.hasError) return AsyncError(b.error!, b.stackTrace!);
  return const AsyncLoading();
}
