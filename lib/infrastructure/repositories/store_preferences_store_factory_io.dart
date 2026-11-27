import 'package:path_provider/path_provider.dart';

import '../../models/repositories/store_preferences_store.dart';
import 'file_store_preferences_store.dart';

StorePreferencesStore? createStorePreferencesStore() =>
    FileStorePreferencesStore(directory: getApplicationDocumentsDirectory);
