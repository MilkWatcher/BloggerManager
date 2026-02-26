# Use Case Compliance Checklist

## Project Overview Alignment

Goal from `use-case.txt`: connect local creators and publishers using a moderated, searchable, geographic database.

Current implementation status:
- ✅ Authentication and account creation (Firebase Auth + Firestore user records)
- ✅ Geographic discovery by radius (5km/10km/25km) with Google Maps integration
- ✅ Tag-based filtering for discovery
- ✅ Blog upload flow with title, description, domain link, tags, location, upload timestamp
- ✅ User dashboard includes "My Uploaded Blogs"

## Main Use Case 1: Blogger Register

Required:
1. Enter credentials (email, username, password)
2. Provide content details (domain link + tags)
3. Provide geolocation via device location
4. Validate mandatory fields
5. Registration submitted

Coverage:
- ✅ Credentials collected in sign-up flow
- ✅ Domain link required at sign-up
- ✅ At least one tag required at sign-up
- ✅ Geolocation requested on post-login onboarding screen
- ✅ City/county/country + coordinates persisted to user profile
- ✅ Validation messages shown for missing mandatory fields

## Main Use Case 2: Search for Blogs

Required:
1. Open search dashboard
2. Search by location radius + tag/category
3. Filter and display matching blog title + domain links

Coverage:
- ✅ Home dashboard supports radius filter chips (5km/10km/25km)
- ✅ Home dashboard supports tag filters
- ✅ Results include blog title, description, domain link, distance, upload time, tags
- ✅ Google Maps quick-open action available per result

## Goals Tracking

- [x] Define schema for blogger info, tags, geolocation
- [x] Set up API/data infrastructure between Flutter and Firestore
- [x] Basic security and privacy controls (authenticated access + ownership rules)
- [x] Simple UI for core Blogger Manager flows

## Deployment Readiness Checks

- ✅ Web build succeeds (`flutter build web`)
- ✅ Firebase Hosting config present in `firebase.json`
- ✅ Firestore composite indexes added in `firestore.indexes.json`
- ✅ Firestore rules configured in `firestore.rules`

## Remaining Production Hardening (Recommended)

- Restrict Google Maps API key by domain/package in Google Cloud Console
- Add consent/privacy policy page and explicit data retention/deletion workflow
- Add automated test coverage (`test/` folder currently absent)
- Add role-based admin moderation authorization (if moderation UI is re-enabled)
