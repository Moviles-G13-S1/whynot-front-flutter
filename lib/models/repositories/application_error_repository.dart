import '../application_error_event.dart';

abstract interface class ApplicationErrorQueue {
  Future<void> add(ApplicationErrorEvent event);
  Future<List<ApplicationErrorEvent>> pending(String userId);
  Future<bool> claim(String eventId, String userId);
  Future<void> remove(String eventId);
}

abstract interface class ApplicationErrorSink {
  Future<void> send(ApplicationErrorEvent event, String userId);
}
