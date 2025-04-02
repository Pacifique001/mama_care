class AssetsHelper {
  const AssetsHelper._();

  // Onboarding Images
  static const String onboardingImage1 = 'assets/svg/onboarding/screen1.svg';
  static const String onboardingImage2 = 'assets/svg/onboarding/screen2.svg';
  static const String onboardingImage3 = 'assets/svg/onboarding/screen3.svg';
  static const String onboardingImage4 = 'assets/svg/onboarding/screen4.svg';

  // Exercise Images - Trimester 1
  static const String walking = 'assets/images/exercise/walking.jpg';
  static const String swimming = 'assets/images/exercise/swimming.jpg';
  static const String yoga = 'assets/images/exercise/yoga.jpg';
  static const String strengthTraining = 'assets/images/exercise/strength-training.jpg';
  static const String stretching = 'assets/images/exercise/stretching.jpg';
  static const String kegels = 'assets/images/exercise/kegels.jpg';

  // Exercise Images - Trimester 2
  static const String prenatalPilates = 'assets/images/exercise/prenatal-pilates.jpg';
  static const String lowImpactAerobics = 'assets/images/exercise/low-impact-aerobics.jpg';
  static const String stationaryCycling = 'assets/images/exercise/stationary-cycling.jpg';
  static const String dancing = 'assets/images/exercise/dancing.jpg';
  static const String squats = 'assets/images/exercise/squats.jpg';
  static const String prenatalYoga = 'assets/images/exercise/prenatal-yoga.jpg';

  // Exercise Images - Trimester 3
  static const String modifiedPlanks = 'assets/images/exercise/modified-planks.jpg';
  static const String wallPushUps = 'assets/images/exercise/wall-push-ups.jpg';
  static const String pelvicTilts = 'assets/images/exercise/pelvic-tilts.jpg';

  // Article Images
  static const String pregnantWoman = 'assets/images/article/pregnant-woman.jpg';
  static const String prenatalYogaArticle = 'assets/images/article/prenatal-yoga.jpg';
  static const String mentalHealthPregnancy = 'assets/images/article/mental-health-pregnancy.png';
  static const String fourthTrimester = 'assets/images/article/fourth-trimester.jpg';
  static const String preparingForLaborDelivery = 'assets/images/article/preparing-for-labor-delivery.jpg';

  // Dashboard Images
  static const String maternalImage = 'assets/svg/dashboard/Maternal.svg';
  static const String timelineIndicator = 'assets/svg/timeline/timeline.svg';
  static const String seedSvg = 'assets/svg/suggested_food/seeds.svg';

  // Pregnancy Detail Images
  static const String babyWeight = 'assets/images/pregnancy detail/pediatrics.png';
  static const String babyHeight = 'assets/images/pregnancy detail/height.png';
  static const String babyCalendar = 'assets/images/pregnancy detail/calendar.png';

  // API URLs
  static const String place_api_base_url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?';
  static const String placePhotoApiBaseUrl = 'https://maps.googleapis.com/maps/api/place/photo?';
  static const String risk_detector_api_base_url = 'https://your-api-url.com/risk-detector?';
  static const String placeApiKey = 'AIzaSyAuDEtq3GqVkYAE-6nn_5pVNdYTBmg9Dr4';

  // Article Data
  static const List<Map<String, dynamic>> articleData = [
    {
      'title': 'Maintaining a Healthy Pregnancy',
      'detail':
          'Nutrition Tips and Strategies for Expectant Mothers" - This article would provide an in-depth look at the importance of maintaining a healthy diet during pregnancy. It could cover topics such as the role of nutrients like folic acid and iron in fetal development, tips for managing pregnancy-related discomforts like morning sickness and food aversions, and strategies for incorporating healthy foods into your diet. The article could also include recipes and meal plans designed specifically for pregnant women.',
      'image': pregnantWoman,
    },
    {
      'title': 'Prenatal Yoga',
      'detail':
          'A Guide to Safe and Effective Yoga Practices for Expectant Mothers" - This article would provide an introduction to the benefits of practicing prenatal yoga during pregnancy. It could cover topics such as the physical and emotional benefits of yoga for expectant mothers, tips for modifying yoga poses to accommodate a growing belly, and precautions to take when practicing yoga during pregnancy. The article could also include a sequence of prenatal yoga poses designed to help expectant mothers relieve common discomforts such as back pain and improve their overall well-being.',
      'image': prenatalYogaArticle,
    },
    {
      'title': 'Preparing for Labor and Delivery',
      'detail':
          'Exercises and Techniques for Expectant Mothers" - This article would provide an overview of exercises and techniques designed to help expectant mothers prepare for labor and delivery. It could cover topics such as kegel exercises to strengthen the pelvic floor muscles, perineal massage to reduce the risk of tearing during delivery, and breathing and relaxation techniques to manage pain during labor. The article could also include advice on how to create a birth plan and what to expect during different stages of labor.',
      'image': preparingForLaborDelivery,
    },
    {
      'title': 'Mental Health and Pregnancy',
      'detail':
          'Strategies for Managing Stress and Anxiety" - This article would provide tips and strategies for managing stress and anxiety during pregnancy. It could cover topics such as the link between stress and pregnancy complications, the importance of self-care during pregnancy, and techniques for managing stress and anxiety, such as mindfulness meditation and cognitive-behavioral therapy. The article could also include advice on how to seek professional help if needed.',
      'image': mentalHealthPregnancy,
    },
    {
      'title': 'The Fourth Trimester',
      'detail':
          'A Guide to Postpartum Recovery and Self-Care" - This article would provide an overview of the "fourth trimester," the period of time after delivery when the mothers body is recovering and adjusting to life with a newborn. It could cover topics such as postpartum physical recovery, the emotional challenges of the postpartum period, and tips for self-care during this time. The article could also include advice on how to seek help if needed, such as from a postpartum doula or mental health professional.',
      'image': fourthTrimester,
    },
  ];

  // Food Data
  static const List<Map<String, dynamic>> foodData = [
    {
      "food_name": "Salmon",
      "description":
          "Salmon is an excellent source of high-quality protein and omega-3 fatty acids, which are essential for the development of the baby's brain and eyes.",
      "category": "Seafood",
    },
    {
      "food_name": "Eggs",
      "description":
          "Eggs are a great source of protein and choline, which is important for the baby's brain development.",
      "category": "Dairy",
    },
    {
      "food_name": "Sweet potatoes",
      "description":
          "Sweet potatoes are rich in beta-carotene, which is converted into vitamin A in the body and is important for the development of the baby's eyes, skin, and immune system.",
      "category": "Vegetables",
    },
    {
      "food_name": "Leafy greens",
      "description":
          "Leafy greens like spinach, kale, and broccoli are rich in vitamins and minerals, including folate, which is important for the baby's brain and spinal cord development.",
      "category": "Vegetables",
    },
    {
      "food_name": "Berries",
      "description":
          "Berries are high in antioxidants and vitamin C, which can help boost the immune system and protect against cell damage.",
      "category": "Fruits",
    },
    {
      "food_name": "Avocado",
      "description":
          "Avocado is rich in healthy fats, fiber, and folate, which is important for the baby's brain and spinal cord development.",
      "category": "Fruits",
    },
    {
      "food_name": "Nuts",
      "description":
          "Nuts like almonds and walnuts are a great source of healthy fats, protein, and fiber, which can help with the baby's growth and development.",
      "category": "Nuts and Seeds",
    },
    {
      "food_name": "Lean meats",
      "description":
          "Lean meats like chicken and beef are a great source of protein and iron, which is important for the baby's growth and development.",
      "category": "Meats",
    },
    {
      "food_name": "Yogurt",
      "description":
          "Yogurt is a great source of calcium and protein, which are important for the baby's bone and muscle development.",
      "category": "Dairy",
    },
    {
      "food_name": "Legumes",
      "description":
          "Legumes like beans, lentils, and chickpeas are a great source of protein, fiber, and folate, which is important for the baby's growth and development.",
      "category": "Beans",
    },
    {
      "food_name": "Whole grains",
      "description":
          "Whole grains like brown rice, quinoa, and oats are a great source of fiber and nutrients, which can help with the baby's growth and development.",
      "category": "Grains",
    },
    {
      "food_name": "Cheese",
      "description":
          "Cheese is a great source of calcium and protein, which are important for the baby's bone and muscle development.",
      "category": "Dairy",
    },
    {
      "food_name": "Fatty fish",
      "description":
          "Fatty fish like tuna and mackerel are a great source of omega-3 fatty acids, which are important for the baby's brain and eye development.",
      "category": "Seafood",
    },
  ];

  // Helper Methods
  static String getExerciseImage(String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'walking':
        return walking;
      case 'swimming':
        return swimming;
      case 'yoga':
        return yoga;
      case 'strength training':
        return strengthTraining;
      case 'stretching':
        return stretching;
      case 'kegels':
        return kegels;
      case 'prenatal pilates':
        return prenatalPilates;
      case 'low impact aerobics':
        return lowImpactAerobics;
      case 'stationary cycling':
        return stationaryCycling;
      case 'dancing':
        return dancing;
      case 'squats':
        return squats;
      case 'prenatal yoga':
        return prenatalYoga;
      case 'modified planks':
        return modifiedPlanks;
      case 'wall push ups':
        return wallPushUps;
      case 'pelvic tilts':
        return pelvicTilts;
      default:
        throw ArgumentError('Exercise image not found for: $exerciseName');
    }
  }

  static String getArticleImage(String articleTitle) {
    switch (articleTitle.toLowerCase()) {
      case 'maintaining a healthy pregnancy':
        return pregnantWoman;
      case 'prenatal yoga':
        return prenatalYogaArticle;
      case 'preparing for labor and delivery':
        return preparingForLaborDelivery;
      case 'mental health and pregnancy':
        return mentalHealthPregnancy;
      case 'the fourth trimester':
        return fourthTrimester;
      default:
        throw ArgumentError('Article image not found for: $articleTitle');
    }
  }

  // Add other asset paths as needed
  static const String baby_weight = 'assets/images/baby_weight.png';
  static const String baby_height = 'assets/images/baby_height.png';
  static const String strength_training = 'assets/images/strength_training.png';
  // Add other image paths
}