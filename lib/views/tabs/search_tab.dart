import 'package:flutter/material.dart';


class SearchTab extends StatelessWidget {
  const SearchTab({super.key});


  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Search something here…'),
      ),
    );
  }
}