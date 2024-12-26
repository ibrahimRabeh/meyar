import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:meyar/BottomNav.dart';
import 'dart:convert';
import 'package:meyar/Colors.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({Key? key}) : super(key: key);

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _quizStarted = false;
  String _currentQuestion = '';
  List<String> _currentOptions = [];
  List<Map<String, dynamic>> _identifiedWeaknesses = [];
  int _questionCount = 0;
  final int _maxQuestions = 6;
  Map<String, dynamic>? _employeeData;
  String _currentArea = ''; // Track which area is being tested

  // ChatGPT API configuration
  final String _apiKey =
      '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'; // Replace with your API key
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    try {
      final String responseString = await DefaultAssetBundle.of(context)
          .loadString('assets/employee.json');
      setState(() {
        _employeeData = jsonDecode(responseString);
      });
    } catch (e) {
      print('Error loading employee data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading employee data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generatePromptBasedOnArea() {
    if (_employeeData == null) return '';

    final employeeInfo = _employeeData!['employeeData'];
    final random =
        DateTime.now().millisecondsSinceEpoch % 7; // Random area selection

    // Select testing area based on performance metrics and random factor
    final kpis = employeeInfo['kpi_objectives'] as List;
    final weakestKpis = kpis.where((kpi) {
      final score = double.tryParse(
              kpi['employee_score'].toString().replaceAll('%', '')) ??
          0;
      return score < 90;
    }).toList();

    Map<String, dynamic> selectedKpi;
    if (weakestKpis.isNotEmpty) {
      selectedKpi = weakestKpis[random % weakestKpis.length];
      _currentArea = selectedKpi['objective'];
    } else {
      selectedKpi = kpis[random % kpis.length];
      _currentArea = selectedKpi['objective'];
    }

    return '''
    Based on this employee data:
    Job Title: ${employeeInfo['employee']['job_title']}
    Department: ${employeeInfo['employee']['department']}
    Testing Area: ${selectedKpi['objective']}
    Current Performance: ${selectedKpi['performance_summary']}
    Key Responsibilities: ${employeeInfo['job_description']['key_responsibilities'].join(', ')}

    Generate a challenging multiple choice question that tests knowledge and skills related to ${selectedKpi['objective']},
    considering that the employee's current performance in this area is: ${selectedKpi['performance_summary']}


    The question should follow these guidelines:
    1. The question should be specific and technical
    2. All answer options must be plausible and realistic
    3. Wrong answers should be common misconceptions or approaches that seem correct at first glance
    4. All options should be of similar length and detail
    5. Avoid obviously incorrect or silly answers
    6. Each wrong answer should be something that someone with partial knowledge might choose
    7. Use industry-standard terminology in all options

    Return the response in JSON format in the following structure it needs to be 100% the same format:
    {
      "question": "technical question related to the area",
      "options": [{
        "text": "the best practice or most accurate approach",
        "isCorrect": true,
        }, 
        {
        "text": "another plausible option",
        "isCorrect": false,
        }, 
        {
        "text": "another plausible option",
        "isCorrect": false,
        }, 
        {
        "text": "another plausible option",
        "isCorrect": false,
        }
      ],
      "area": "${selectedKpi['objective']}",
      "difficulty": "challenging",
      "explanation": "Brief explanation of why the correct answer is best and why the others fall short"
    }
    
    Example of good options:
    - For a data quality question:
      ✓ "Implement automated data validation with both syntax and semantic checks"
      ✓ "Validate data only after it's been transformed and loaded"
      ✓ "Rely on end-user reporting to identify data quality issues"
      ✓ "Perform manual spot checks on random data samples"

    Example of bad options (avoid these):
      "Don't check the data at all"
      "Delete all invalid data"
      "Ask someone else to do it"
      "Ignore data quality completely"
    ''';
  }

  Future<Map<String, dynamic>> _generateQuestion(
      {bool isCorrect = true}) async {
    if (_employeeData == null) {
      await _loadEmployeeData();
      if (_employeeData == null) {
        print('Error loading employee data');
        return _getFallbackQuestion();
      }
    }

    setState(() => _isLoading = true);

    try {
      final employeeInfo = _employeeData!['employeeData'];
      final kpiObjectives = employeeInfo['kpi_objectives'] as List;

      String prompt;
      if (!_quizStarted) {
        prompt = _generatePromptBasedOnArea();
      } else {
        // Find the current KPI objective safely
        Map<String, dynamic> currentKpi;
        try {
          currentKpi = kpiObjectives.firstWhere(
              (kpi) => kpi['objective'] == _currentArea,
              orElse: () => kpiObjectives.first);
        } catch (e) {
          currentKpi = kpiObjectives.first;
        }

        _currentArea = currentKpi?['objective'];

        prompt = '''
        Previous answer was ${isCorrect ? 'correct' : 'incorrect'} in the area of $_currentArea.
        ${isCorrect ? 'Test another aspect' : 'Dig deeper into this area'}.
        
        Employee Context:
        ${employeeInfo['job_description']['purpose']}
        
        Generate another relevant question, considering the performance summary: 
        ${currentKpi['performance_summary']}
        
    Generate a challenging multiple choice question that tests knowledge and skills related to ${currentKpi['objective']},
    considering that the employee's current performance in this area is: ${currentKpi['performance_summary']}


    The question should follow these guidelines:
    1. The question should be specific and technical
    2. All answer options must be plausible and realistic
    3. Wrong answers should be common misconceptions or approaches that seem correct at first glance
    4. All options should be of similar length and detail
    5. Avoid obviously incorrect or silly answers
    6. Each wrong answer should be something that someone with partial knowledge might choose
    7. Use industry-standard terminology in all options

    Return the response in JSON format in the following structure it needs to be 100% the same format:
    {
      "question": "technical question related to the area",
      "options": [{
        "text": "the best practice or most accurate approach",
        "isCorrect": true,
        }, 
        {
        "text": "another plausible option",
        "isCorrect": false,
        }, 
        {
        "text": "another plausible option",
        "isCorrect": false,
        }, 
        {
        "text": "another plausible option",
        "isCorrect": false,
        }
      ],
      "area": "${currentKpi['objective']}",
      "difficulty": "challenging",
      "explanation": "Brief explanation of why the correct answer is best and why the others fall short"
    }
    
    Example of good options:
    - For a data quality question:
      ✓ "Implement automated data validation with both syntax and semantic checks"
      ✓ "Validate data only after it's been transformed and loaded"
      ✓ "Rely on end-user reporting to identify data quality issues"
      ✓ "Perform manual spot checks on random data samples"

    Example of bad options (avoid these):
      "Don't check the data at all"
      "Delete all invalid data"
      "Ask someone else to do it"
      "Ignore data quality completely"
    ''';
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String contentString = data['choices'][0]['message']['content'];
        print('Debug - API Response: $contentString'); // Add debug print

        try {
          final Map<String, dynamic> questionData = jsonDecode(contentString);
          return questionData;
        } catch (e) {
          print('Error parsing API response: $e');
          return _getFallbackQuestion();
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate question: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating question: $e');
      return _getFallbackQuestion();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _getFallbackQuestion() {
    String area = 'Data Analysis';

    try {
      if (_employeeData != null) {
        final kpiObjectives =
            _employeeData!['employeeData']['kpi_objectives'] as List;
        if (kpiObjectives.isNotEmpty) {
          area = kpiObjectives[0]['objective'];
        }
      }
    } catch (e) {
      print('Error getting fallback area: $e');
    }

    // Set the current area for consistency
    _currentArea = area;

    // Return a relevant fallback question based on the job description
    return {
      'question':
          'What is the most effective approach to improve data quality in business intelligence?',
      'options': [
        {
          'text':
              'Implement automated validation with real-time monitoring and alerts',
          "isCorrect": true,
        },
        {
          'text': 'Wait for end-users to report data inconsistencies',
          "isCorrect": false,
        },
        {
          'text': 'Review data quality only during quarterly audits',
          "isCorrect": false,
        },
        {
          'text': 'Perform manual data validation on a random sample',
          "isCorrect": false,
        }
      ],
      'area': area,
      'explanation':
          'Automated validation with real-time monitoring provides immediate detection and resolution of data quality issues, ensuring continuous data integrity.'
    };
  }

  Future<void> _startQuiz() async {
    if (!mounted) return;

    try {
      setState(() => _quizStarted = true);
      final questionData = await _generateQuestion();

      if (!mounted) return;

      // Safely extract and validate the data
      final question = questionData['question'] ?? 'Error loading question';
      final options = (questionData['options'] as List?)
              ?.map((e) => e["text"].toString())
              .toList() ??
          ['Option 1', 'Option 2', 'Option 3', 'Option 4'];
      final area = questionData['area']?.toString() ?? 'General Knowledge';

      setState(() {
        _currentQuestion = question;
        _currentOptions = options;
        _currentArea = area;
        _questionCount++;
      });
    } catch (e) {
      print('Error starting quiz: $e');
      if (mounted) {
        setState(() {
          _currentQuestion =
              'What is the most important aspect of data quality?';
          _currentOptions = [
            'Data validation and verification',
            'Regular data auditing',
            'Consistent data formatting',
            'Automated error checking'
          ];
          _currentArea = 'Data Quality';
          _questionCount++;
        });
      }
    }
  }

  Future<void> _handleAnswer(int selectedIndex) async {
    if (_questionCount >= _maxQuestions) {
      await _generateCourseRecommendations();
      return;
    }

    final isCorrect = selectedIndex == 0;
    if (!isCorrect && _employeeData != null) {
      // Safely find the current KPI objective
      final kpiObjectives =
          _employeeData!['employeeData']['kpi_objectives'] as List;
      final currentKpi = kpiObjectives.firstWhere(
          (kpi) => kpi['objective'].toString() == _currentArea,
          orElse: () =>
              {'performance_summary': 'No performance data available'});

      _identifiedWeaknesses.add({
        'area': _currentArea,
        'question': _currentQuestion,
        'current_performance': currentKpi['performance_summary']
      });
    }

    if (!mounted) return;

    try {
      final questionData = await _generateQuestion(isCorrect: isCorrect);
      print('Debug - Question Data: $questionData'); // Add debug print

      if (!mounted) return;

      // Safely extract and validate the question data
      final question = questionData['question']?.toString() ??
          'What is the most important aspect of data quality?';
      final optionsList = questionData['options'];

      List<String> options;
      if (optionsList is List) {
        options = optionsList.map((e) => e['text'].toString()).toList();
      } else {
        options = [
          'Data validation and verification',
          'Regular data auditing',
          'Consistent data formatting',
          'Automated error checking'
        ];
        print('Debug - Invalid options format: $optionsList');
      }

      final area = questionData['area']?.toString() ?? 'General Knowledge';

      setState(() {
        _currentQuestion = question;
        _currentOptions = options;
        _currentArea = area;
        _questionCount++;
      });
    } catch (e) {
      print('Error handling answer: $e');
      if (mounted) {
        setState(() {
          _currentQuestion =
              'What is the most important aspect of data quality?';
          _currentOptions = [
            'Data validation and verification',
            'Regular data auditing',
            'Consistent data formatting',
            'Automated error checking'
          ];
          _currentArea = 'Data Quality';
          _questionCount++;
        });
      }
    }
  }

  Future<void> _generateCourseRecommendations() async {
    if (_employeeData == null || _identifiedWeaknesses.isEmpty) return;

    final prompt = '''
    Based on these identified weaknesses:
    ${_identifiedWeaknesses.map((w) => 'Area: ${w['area']}, Current Performance: ${w['current_performance']}').join('\n')}
    
    And considering the employee's overall performance:
    ${_employeeData!['employeeData']['overall_performance']['performance_rating']}
    
    Recommend specific training courses or development activities to address these gaps.
    Consider both technical skills and soft skills needed for a ${_employeeData!['employeeData']['employee']['job_title']}.
    ''';

    // Implement course recommendation logic here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: MediaQuery.of(context).size.width >= 600
            ? IconButton(
                icon: Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        centerTitle: true,
        title: Text('Skill Assessment',
            style: TextStyle(color: AppColors.backgroundColor)),
      ),
      drawer: MediaQuery.of(context).size.width >= 600
          ? ResponsiveNavBar(index: 3) // Set index based on current page
          : null,
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? ResponsiveNavBar(index: 3) // Set index based on current page
          : null,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryColor,
                ),
              )
            : !_quizStarted
                ? _buildStartScreen()
                : _buildQuizScreen(),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready to assess your skills?',
            style: TextStyle(
              fontSize: 24,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'This assessment will analyze your performance and suggest targeted improvements.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Start Assessment',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: _questionCount / _maxQuestions,
          backgroundColor: AppColors.dividerColor,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryColor),
        ),
        SizedBox(height: 30),
        Text(
          'Question $_questionCount of $_maxQuestions',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Area: $_currentArea',
          style: TextStyle(
            color: AppColors.secondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text(
          _currentQuestion,
          style: TextStyle(
            fontSize: 22,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 40),
        ..._currentOptions.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ElevatedButton(
              onPressed: () => _handleAnswer(entry.key),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundColor,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.dividerColor),
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
