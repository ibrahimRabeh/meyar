import 'package:flutter/material.dart';
import 'package:meyar/Colors.dart';

class ResponsiveNavBar extends StatefulWidget {
  final int index;
  const ResponsiveNavBar({super.key, required this.index});

  @override
  _ResponsiveNavBarState createState() => _ResponsiveNavBarState();
}

class _ResponsiveNavBarState extends State<ResponsiveNavBar> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
  }

  void _onItemSelected(int index) {
    setState(() {
      _currentIndex = index;
      switch (index) {
        case 3:
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/Quiz', (route) => false);
          break;
        case 2:
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/Courses', (route) => false);
          break;
        case 1:
        case 0:
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          break;
      }
    });
  }

  List<NavigationItem> get _navigationItems => [
        NavigationItem(Icons.account_circle_outlined, 'حسابي'),
        NavigationItem(Icons.message_outlined, 'something'),
        NavigationItem(Icons.bookmark_add, 'Courses'),
        NavigationItem(Icons.receipt_outlined, 'Test'),
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile bottom navigation
          return BottomNavigationBar(
            backgroundColor: AppColors.textPrimary,
            items: _navigationItems
                .map((item) => BottomNavigationBarItem(
                      backgroundColor: AppColors.primaryColor,
                      icon: Icon(item.icon),
                      label: item.label,
                    ))
                .toList(),
            currentIndex: _currentIndex,
            selectedItemColor: AppColors.dividerColor,
            unselectedItemColor: AppColors.textSecondary,
            showUnselectedLabels: true,
            onTap: _onItemSelected,
          );
        } else {
          // Desktop drawer navigation
          return Drawer(
            child: Container(
              color: AppColors.textPrimary,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
                child: ListView(
                  children: [
                    ..._navigationItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return ListTile(
                        leading: Icon(
                          item.icon,
                          color: _currentIndex == index
                              ? AppColors.dividerColor
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: _currentIndex == index
                                ? AppColors.dividerColor
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: _currentIndex == index,
                        onTap: () => _onItemSelected(index),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;

  NavigationItem(this.icon, this.label);
}
