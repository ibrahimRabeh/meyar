import 'package:flutter/material.dart';
import 'package:meyar/Courses.dart';
import 'package:meyar/CoursesDetails.dart';
import 'package:meyar/Quiz.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meyar',
      home: QuizPage(),
      routes: {
        '/Quiz': (context) => QuizPage(),
        '/Courses': (context) => CoursesPage(),
        'CoursesDetails': (context) => CourseDetailsPage(
              course: {},
            ),
      },
    );
  }
}
