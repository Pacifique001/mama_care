import 'package:flutter/foundation.dart';
import 'package:mama_care/domain/usecases/timeline_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

class TimelineViewModel extends ChangeNotifier {
  final TimelineUseCase _timelineUseCase;
  final DatabaseHelper _databaseHelper;

  TimelineViewModel({
    required TimelineUseCase timelineUseCase,
    required DatabaseHelper databaseHelper,
  }) : _timelineUseCase = timelineUseCase,
       _databaseHelper = databaseHelper {
    initialize();
  }

  PregnancyDetails? _pregnancyDetails;
  bool _isLoading = false;
  String? _errorMessage;

  // Pregnancy timeline data
  final List<List<String>> weeks = [
    [
      'Week 1',
      'Your body is preparing for ovulation. The menstrual cycle begins, counting towards your estimated due date.',
    ],
    [
      'Week 2',
      'Ovulation occurs, and conception may happen during this period.',
    ],
    [
      'Week 3',
      'The fertilized egg implants in the uterus, starting embryo development.',
    ],
    [
      'Week 4',
      'Your baby is now the size of a poppy seed, and their heart begins to form.',
    ],
    [
      'Week 5',
      'The neural tube starts developing into the brain and spinal cord.',
    ],
    [
      'Week 6',
      'Your baby\'s heart is beating, and tiny buds for arms and legs appear.',
    ],
    ['Week 7', 'Facial features like nostrils and eyes start forming.'],
    ['Week 8', 'Your baby\'s fingers and toes start to develop.'],
    [
      'Week 9',
      'Essential organs like the liver, brain, and heart continue growing.',
    ],
    ['Week 10', 'The baby is moving, but you can\'t feel it yet.'],
    ['Week 11', 'Your baby\'s bones are hardening, and tooth buds appear.'],
    ['Week 12', 'Your baby\'s intestines start moving into the abdomen.'],
    ['Week 13', 'Your baby now has fingerprints, and vocal cords are forming.'],
    [
      'Week 14',
      'Hair follicles start appearing, and your baby begins making facial expressions.',
    ],
    ['Week 15', 'Your baby\'s skeletal system is developing rapidly.'],
    [
      'Week 16',
      'Your baby\'s hearing is developing, and limb movements become more coordinated.',
    ],
    ['Week 17', 'Your baby is practicing swallowing and sucking reflexes.'],
    [
      'Week 18',
      'Your baby\'s ears are fully developed and can hear outside noises.',
    ],
    [
      'Week 19',
      'Your baby\'s skin starts forming vernix, a protective coating.',
    ],
    ['Week 20', 'Halfway there! Your baby is the size of a banana.'],
    [
      'Week 21',
      'Your baby is tasting amniotic fluid and developing taste buds.',
    ],
    [
      'Week 22',
      'Your baby\'s senses are refining, and fingerprints are forming.',
    ],
    ['Week 23', 'Your baby\'s lungs are developing to prepare for breathing.'],
    [
      'Week 24',
      'Your baby\'s face is fully formed, and they may respond to touch.',
    ],
    ['Week 25', 'Your baby is gaining fat, making skin less translucent.'],
    [
      'Week 26',
      'Your baby\'s eyes start opening, and they can distinguish light and dark.',
    ],
    ['Week 27', 'Your baby\'s brain activity increases significantly.'],
    ['Week 28', 'Your baby is now capable of dreaming.'],
    ['Week 29', 'Your baby\'s muscles and lungs continue developing.'],
    ['Week 30', 'Your baby is practicing breathing with amniotic fluid.'],
    [
      'Week 31',
      'Your baby starts storing essential minerals like iron and calcium.',
    ],
    ['Week 32', 'Your baby likely assumes a head-down position for birth.'],
    ['Week 33', 'Your baby\'s immune system is developing.'],
    ['Week 34', 'Your baby\'s nails and hair are fully formed.'],
    ['Week 35', 'Your baby\'s nervous system is nearly mature.'],
    ['Week 36', 'Your baby\'s head is likely engaged in the pelvis.'],
    ['Week 37', 'Your baby is considered full-term.'],
    ['Week 38', 'Your baby is developing final fat stores for warmth.'],
    ['Week 39', 'Your baby\'s brain continues to grow rapidly.'],
    ['Week 40', 'Your baby is ready for birth!'],
  ];

  // Current pregnancy state
  DateTime _dueDate = DateTime.now().add(const Duration(days: 280));
  int _weeksPregnant = 0;
  int _daysPregnant = 0;
  final double _babyHeight = 0.0;
  final double _babyWeight = 0.0;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get weeksPregnant => _weeksPregnant;
  int get daysPregnant => _daysPregnant;
  DateTime get dueDate => _dueDate;

  void initialize() {
    _calculateCurrentProgress();
  }

  Future<void> fetchPregnancyDetails() async {
    try {
      _updateState(isLoading: true, errorMessage: null);

      final details = await _timelineUseCase.getPregnancyDetails();
      if (details != null) {
        _updateFromDetails(details);
        await _cacheLocally(details);
      }
    } catch (e) {
      _handleError('Failed to fetch details: ${e.toString()}');
    } finally {
      _updateState(isLoading: false);
    }
  }

  void updateDueDate(DateTime newDate) {
    if (newDate.isBefore(DateTime.now())) return;

    _dueDate = newDate;
    _calculateCurrentProgress();
    notifyListeners();
  }

  String getWeekDescription(int weekNumber) {
    if (weekNumber < 1 || weekNumber > weeks.length) return '';
    return weeks[weekNumber - 1][1];
  }

  // Core calculation logic
  void _calculateCurrentProgress() {
    final lmpDate = _dueDate.subtract(const Duration(days: 280));
    final pregnancyDuration = DateTime.now().difference(lmpDate);

    _weeksPregnant = (pregnancyDuration.inDays ~/ 7) + 1;
    _daysPregnant = pregnancyDuration.inDays % 7;

    // Clamp values to valid range
    _weeksPregnant = _weeksPregnant.clamp(0, weeks.length);
    _daysPregnant = _daysPregnant.clamp(0, 6);

    notifyListeners();
  }

  // Private methods
  void _updateFromDetails(PregnancyDetails details) {
    _dueDate = details.dueDate;
    _calculateCurrentProgress();
  }

  void _updateState({bool? isLoading, String? errorMessage}) {
    if (isLoading != null) _isLoading = isLoading;
    if (errorMessage != null) _errorMessage = errorMessage;
    notifyListeners();
  }

  void _handleError(String message) {
    _errorMessage = message;
    _updateState(isLoading: false);
    debugPrint(message);
  }

  Future<void> _cacheLocally(PregnancyDetails details) async {
    try {
      await _databaseHelper.upsertPregnancyDetail(details.toJson());
    } catch (e) {
      debugPrint('Local cache error: $e');
    }
  }
}
