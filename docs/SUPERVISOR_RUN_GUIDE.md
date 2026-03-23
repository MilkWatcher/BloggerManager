# Supervisor Run Guide — Blogger Manager

## Access the Deployed Software
Use the live deployed version (no local setup required):

**URL:** https://bloggermanager-f1e21.web.app

## How to Run and Review
1. Open the URL above in a modern browser (Chrome, Edge, or Firefox).
2. Create an account via **Sign Up** or use an existing login.
3. Complete profile setup (display name, tags, location approval) if prompted.
4. Navigate core areas:
   - **Home/Search**: Browse blog cards and open blog links/maps.
   - **Browse Bloggers**: View blogger profiles and authored blogs.
   - **Upload Blog**: Add or edit blog entries with metadata and image.
   - **My Profile**: Review and edit your personal profile.

## Notes for Supervisors
- The application is hosted on Firebase Hosting and updates are deployed to the same URL.
- Geolocation prompts may appear depending on feature usage.
- If the first load appears cached, perform a hard refresh (`Ctrl+F5`).

## Optional Local Run (Developer Mode)
If needed, the app can also be run locally from source:
1. `flutter pub get`
2. `flutter run -d chrome`
