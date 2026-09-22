# Rules for the release build's code shrinker (R8). Flutter and its plugins bring
# their own keep rules; only add here what a release-mode crash shows is needed.

# Optional Play Core classes that Flutter references but this app doesn't ship.
-dontwarn com.google.android.play.core.**
