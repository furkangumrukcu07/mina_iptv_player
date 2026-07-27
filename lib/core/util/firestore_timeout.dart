import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralised Firestore timeout helper.
///
/// Wraps a Firestore `Future` with a configurable timeout (default 8 seconds).
/// If the timeout expires a `TimeoutException` is thrown, allowing the caller
/// to fallback to cache or ignore the request without blocking the UI thread.
Future<T> withFirestoreTimeout<T>(Future<T> future, {Duration timeout = const Duration(seconds: 8)}) {
  return future.timeout(timeout, onTimeout: () {
    throw TimeoutException('Firestore operation timed out after ${timeout.inSeconds}s');
  });
}
