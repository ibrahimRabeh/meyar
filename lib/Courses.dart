import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:meyar/BottomNav.dart';
import 'package:meyar/Colors.dart';
import 'package:meyar/CoursesDetails.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({Key? key}) : super(key: key);

  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  List<dynamic> allCourses = [];
  List<dynamic> suggestedCourses = [];
  List<dynamic> displayedCourses = [];
  Map<String, List<dynamic>> coursesByCategory = {};
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    loadCourseData();
  }

  Future<void> loadCourseData() async {
    try {
      // Load course data
      final String courseJson =
          await rootBundle.loadString('assets/courses.json');
      final courseData = json.decode(courseJson);
      allCourses = courseData['courses'];

      // Load suggested courses if available
      try {
        suggestedCourses = [];
      } catch (e) {
        // No suggestions available
        suggestedCourses = [];
      }

      // Organize courses by category
      coursesByCategory = {};
      for (var course in allCourses) {
        final category = course['category'];
        if (!coursesByCategory.containsKey(category)) {
          coursesByCategory[category] = [];
        }
        coursesByCategory[category]!.add(course);
      }

      setState(() {
        displayedCourses = allCourses;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading course data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void searchCourses(String query) {
    if (query.isEmpty) {
      setState(() {
        displayedCourses = allCourses;
      });
      return;
    }

    // Create searchable items with weighted attributes
    final fuse = Fuzzy(
      allCourses,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'title',
            getter: (item) => (item as Map<String, dynamic>)['title'] ?? '',
            weight: 0.5,
          ),
          WeightedKey(
            name: 'category',
            getter: (item) => (item as Map<String, dynamic>)['category'] ?? '',
            weight: 0.3,
          ),
          WeightedKey(
            name: 'tags',
            getter: (item) =>
                (item as Map<String, dynamic>)['tags'].join(' ') ?? '',
            weight: 0.2,
          ),
        ],
      ),
    );

    final result = fuse.search(query);
    setState(() {
      displayedCourses = result.map((r) => r.item).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        centerTitle: true,
        title: const Text(
          'Available Courses',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchBar(
              controller: searchController,
              onChanged: searchCourses,
              hintText: 'Search courses...',
            ),
          ),
        ),
        leading: MediaQuery.of(context).size.width >= 600
            ? IconButton(
                icon: Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
      ),
      drawer: MediaQuery.of(context).size.width >= 600
          ? ResponsiveNavBar(index: 2) // Set index based on current page
          : null,
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? ResponsiveNavBar(index: 2) // Set index based on current page
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (suggestedCourses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Suggested Courses',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SuggestedCoursesSection(courses: suggestedCourses),
              Divider(
                height: 32,
                color: AppColors.dividerColor,
                thickness: 1,
              ),
            ],
            if (searchController.text.isEmpty)
              _buildCategorizedCourses()
            else
              _buildSearchResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedCourses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: coursesByCategory.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: entry.value.length,
                itemBuilder: (context, index) {
                  return CourseCard(course: entry.value[index]);
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: displayedCourses
            .map((course) => CourseCard(course: course))
            .toList(),
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;

  const CourseCard({Key? key, required this.course}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsPage(course: course),
          ),
        );
      },
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.asset(
                    course['image'],
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        course['level'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course['duration'],
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: AppColors.accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course['rating'].toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuggestedCoursesSection extends StatelessWidget {
  final List<dynamic> courses;

  const SuggestedCoursesSection({Key? key, required this.courses})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                CourseCard(course: courses[index]),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Suggested',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;

  const SearchBar({
    Key? key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      style: TextStyle(color: AppColors.textPrimary),
    );
  }
}
