import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/category_catalog.dart';
import '../../models/city.dart';
import '../../models/user_profile.dart';
import '../../controllers/live_section.dart';
import '../../controllers/profile_load_controller.dart';
import '../../controllers/rebuild_trace.dart';
import '../widgets/profile_data_notice.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/form_controls.dart';
import '../widgets/profile_controls.dart';
import '../widgets/selected_listenable_builder.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileLoadController? _loads;
  Listenable? _status;
  Widget? _content;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deps = context.dependencies;
    if (deps.profileController.currentUserId == null || _loads != null) return;
    final loads = _loads = ProfileLoadController(
      errorReporter: deps.errorReporter,
      connectivity: deps.connectivity,
      watchProfile: deps.profileController.watchCurrentProfile,
      getCities: deps.cityController.getCities,
    );
    _status = Listenable.merge([loads.profile, deps.connectivity]);
    _content = _ProfileContent(loads: loads, status: _status!);
  }

  @override
  void dispose() {
    _loads?.dispose();
    super.dispose();
  }

  String _loadState() {
    final section = _loads!.profile;
    if (section.visibleSnapshot.connectionState == ConnectionState.waiting) {
      return 'loading';
    }
    if (section.snapshot.hasError && !section.hasValue) return 'error';
    if (section.visibleSnapshot.hasData) return 'ready';
    return context.dependencies.connectivity.isOffline
        ? 'empty-offline'
        : 'empty';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: context.dependencies.profileController.currentUserId == null
          ? const Center(child: Text('No user logged in.'))
          : SelectedListenableBuilder<String>(
              listenable: _status!,
              select: _loadState,
              child: _content,
              builder: (context, state, child) {
                if (state == 'ready') return child!;
                if (state == 'loading') {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state == 'error') {
                  return Center(
                    child: TextButton(
                      onPressed: _loads!.profile.start,
                      child: const Text('Could not load profile. Try again'),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state == 'empty-offline'
                            ? 'No profile available offline on this device.'
                            : 'Profile not found.',
                      ),
                      TextButton(
                        onPressed: _loads!.profile.start,
                        child: const Text('Retry profile'),
                      ),
                    ],
                  ),
                );
              },
            ),
    ),
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 4),
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.loads, required this.status});
  final ProfileLoadController loads;
  final Listenable status;
  @override
  Widget build(BuildContext context) {
    RebuildTrace.record('Profile content');
    final deps = context.dependencies;
    final controller = deps.profileController;
    final section = loads.profile;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 39, 24, 130),
      child: Column(
        children: [
          SelectedListenableBuilder<
            ({bool pending, bool cached, bool offline, bool failed})
          >(
            listenable: status,
            select: () => (
              pending: section.visibleSnapshot.data?.hasPendingWrites == true,
              cached: section.visibleSnapshot.data?.fromCache == true,
              offline: deps.connectivity.isOffline,
              failed: section.snapshot.hasError,
            ),
            builder: (context, value, _) => ProfileDataNotice(
              profile: section.visibleSnapshot.data,
              offline: value.offline,
              failed: value.failed,
              onRetry: section.start,
            ),
          ),
          SelectedListenableBuilder<String?>(
            listenable: section,
            select: () => section.visibleSnapshot.data?.photoPath,
            builder: (context, path, _) => ProfileAvatar(
              photoPath: path,
              loadPhotoUrl: controller.getPhotoUrl,
              loadPhotoBytes: controller.getPhotoBytes,
              connectivity: deps.connectivity,
              cacheManager: deps.photoCacheManager,
            ),
          ),
          const SizedBox(height: 31),
          SelectedListenableBuilder<String>(
            listenable: section,
            select: () {
              final name = section.visibleSnapshot.data?.name ?? '';
              return name.isEmpty ? 'User' : name;
            },
            builder: (context, name, _) =>
                Text(name, style: WhyNotTextStyles.serif(size: 30)),
          ),
          const SizedBox(height: 45),
          FormSurface(
            padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SelectedProfileValue(
                  section: section,
                  label: 'Email',
                  select: (p) => p.email,
                ),
                _SelectedProfileValue(
                  section: section,
                  label: 'Gender',
                  select: (p) => p.gender,
                ),
                _SelectedProfileValue(
                  section: section,
                  label: 'Age',
                  select: (p) => p.age.toString(),
                ),
                SelectedListenableBuilder<String?>(
                  listenable: section,
                  select: () => section.visibleSnapshot.data?.cityId,
                  builder: (context, cityId, _) => cityId == null
                      ? const ProfileValue(label: 'City', value: 'Not selected')
                      : _ProfileCityValue(cityId: cityId, cities: loads.cities),
                ),
                const _PasswordValue(),
                _SelectedProfileValue(
                  section: section,
                  label: 'Preferred Category',
                  isLast: true,
                  select: (p) =>
                      CategoryCatalog.labelsById[p.preferredCategoryId] ??
                      'Not selected',
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const _ProfileActions(),
        ],
      ),
    );
  }
}

class _SelectedProfileValue extends StatelessWidget {
  const _SelectedProfileValue({
    required this.section,
    required this.label,
    required this.select,
    this.isLast = false,
  });
  final LiveSection<UserProfile?> section;
  final String label;
  final String Function(UserProfile) select;
  final bool isLast;
  @override
  Widget build(BuildContext context) => SelectedListenableBuilder<String>(
    listenable: section,
    select: () {
      final profile = section.visibleSnapshot.data;
      return profile == null ? '' : select(profile);
    },
    builder: (context, value, _) =>
        ProfileValue(label: label, value: value, isLast: isLast),
  );
}

class _PasswordValue extends StatelessWidget {
  const _PasswordValue();
  @override
  Widget build(BuildContext context) => ProfileValue(
    label: 'Password',
    value: '********',
    onTap: () => Navigator.pushNamed(context, AppRoutes.changePassword),
  );
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions();
  Future<void> _logOut(BuildContext context) async {
    try {
      await context.dependencies.authController.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.editProfile),
          style: linkButtonStyle(),
          icon: SvgPicture.asset(
            'assets/figma/edit_profile.svg',
            width: 13,
            height: 13,
          ),
          label: const Text('Edit Profile'),
        ),
      ),
      const SizedBox(height: 38),
      SizedBox(
        width: 190,
        child: PillButton(label: 'Log Out', onPressed: () => _logOut(context)),
      ),
    ],
  );
}

class _ProfileCityValue extends StatelessWidget {
  const _ProfileCityValue({required this.cityId, required this.cities});
  final String cityId;
  final LiveSection<List<City>> cities;
  ({String value, bool failed}) _select() {
    final snapshot = cities.visibleSnapshot;
    final failed = cities.snapshot.hasError && !cities.hasValue;
    final city = snapshot.data?.where((item) => item.id == cityId).firstOrNull;
    return (
      value:
          city?.name ??
          (snapshot.connectionState == ConnectionState.waiting
              ? 'Loading city...'
              : 'City unavailable'),
      failed: failed,
    );
  }

  @override
  Widget build(BuildContext context) =>
      SelectedListenableBuilder<({String value, bool failed})>(
        listenable: cities,
        select: _select,
        builder: (context, value, _) => value.failed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileValue(label: 'City', value: 'City unavailable'),
                  TextButton(
                    onPressed: cities.start,
                    child: const Text('Retry city'),
                  ),
                ],
              )
            : ProfileValue(label: 'City', value: value.value),
      );
}
