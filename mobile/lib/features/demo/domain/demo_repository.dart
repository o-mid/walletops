import '../data/demo_models.dart';

abstract class DemoRepository {
  Future<DemoSimulateResult> simulate({
    int count = 1,
    bool ensureDemoRule = true,
  });
}
