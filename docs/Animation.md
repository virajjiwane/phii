# Add Animations
## For smooth transitions:

```dart
Hero(
  tag: 'unique-tag',
  child: YourWidget(),
)

// Or use AnimatedContainer for implicit animations
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // properties that change
)
```