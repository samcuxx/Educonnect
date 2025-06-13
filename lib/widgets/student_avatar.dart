import 'package:flutter/material.dart';

class StudentAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;

  const StudentAvatar({
    Key? key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundImage:
          (imageUrl != null && imageUrl!.isNotEmpty)
              ? NetworkImage(imageUrl!)
              : null,
      child:
          (imageUrl == null || imageUrl!.isEmpty)
              ? Text(
                name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              )
              : null,
    );
  }
}
