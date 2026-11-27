// Files need dart:io, which Flutter Web does not have; Web keeps the default
// order for the session instead.
export 'store_preferences_store_factory_stub.dart'
    if (dart.library.io) 'store_preferences_store_factory_io.dart';
