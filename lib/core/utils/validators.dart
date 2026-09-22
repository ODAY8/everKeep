/// Shortest password Supabase accepts by default. If you raise the minimum in
/// your project's Auth settings, raise this to match so people are told up front.
const int minPasswordLength = 6;

final RegExp _emailPattern = RegExp(r'^[\w.+\-]+@([a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,}$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// A message describing why [password] is unacceptable, or null if it's fine.
String? validatePassword(String password) {
  if (password.isEmpty) return 'Password is required';
  if (password.length < minPasswordLength) {
    return 'Password must be at least $minPasswordLength characters';
  }
  return null;
}
