import 'package:path_provider/path_provider.dart';
import '../../models/repositories/profile_draft_store.dart';
import 'file_profile_draft_store.dart';

ProfileDraftStore createProfileDraftStore() =>
    FileProfileDraftStore(directory: getApplicationDocumentsDirectory);
