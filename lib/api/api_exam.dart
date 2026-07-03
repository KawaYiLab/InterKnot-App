part of 'api.dart';

extension ExamApi on Api {
  Future<ExamStatus> getExamStatus() async {
    final res = await get('/api/exam/status');
    final data = unwrapData<Map<String, dynamic>>(res);
    return ExamStatus.fromJson(data);
  }

  Future<ExamStartResult> startExam() async {
    final res = await post('/api/exam/start', {});
    final data = unwrapData<Map<String, dynamic>>(res);
    return ExamStartResult.fromJson(data);
  }

  Future<ExamSubmitResult> submitExam(
    String attemptId,
    Map<String, List<String>> answers,
  ) async {
    final res = await post('/api/exam/submit', {
      'attemptId': attemptId,
      'answers': answers,
    });
    final data = unwrapData<Map<String, dynamic>>(res);
    return ExamSubmitResult.fromJson(data);
  }
}
