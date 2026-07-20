# CLAUDE.md — Restaurant Recommender

## What this project is
An instructor-guided learning project: an iOS app that recommends restaurants.
- `API/` — Python FastAPI backend: JWT auth (access + refresh tokens, refresh
  in httpOnly cookie), PostgreSQL via SQLAlchemy (docker compose), Google
  Places v1 integration in `location.py`. Only the users table is used so far;
  restaurant/review/preference tables exist but nothing writes to them.
- `Restaurant Recommender/` — SwiftUI iOS client: Keychain token storage,
  actor-based APIClient with single-flight 401 refresh, typed Endpoints,
  snake_case JSON coding.

## About me (the developer) — teach, don't just solve
I'm learning Swift and app development. This project is instructor-guided, so
some advanced patterns in the codebase (actor APIClient, single-flight
refresh) were scaffolded FOR me — do not assume I fully own them yet.

My current skill profile (last updated 2026-07-19):
- Solid: overall architecture instincts, backend/auth concepts, willingness
  to trace code. Building new features by imitating existing patterns —
  RegisterView and FunctionManager were both built solo by pattern-matching
  AuthManager/LoginView, and the first authenticated feature endpoint
  (find_restaurants: Endpoint + DTO + manager + view) was wired without help.
  NEW (2026-07-19): built the whole restaurant-details flow solo across both
  layers (place_details + route + Endpoint + DTO + manager + sheet view), and
  when given a review list, applied two fixes himself mid-session (snake_case
  contract fix in place_details, auth Depends on /find_restaurants) before
  the instructor could — applies feedback fast when the why is clear.
- Prefers concise explanations over long teaching prose ("explain stuff more
  simply, I'm not trying to read all that") — keep hints/reviews short and
  concrete; and after one hint pass he may just ask for the changes directly.
- Learning: SwiftUI fluency (views, forms, navigation), CoreLocation,
  @Observable vs ObservableObject — mid-migration, and currently being done
  as annotation-swapping rather than conceptually (see @State-in-class bug
  below), Swift conventions (naming, access control, avoiding dead code,
  trailing semicolons keep appearing).
- Known past mistakes to watch for:
  - Layer mismatches (frontend payload not matching backend Pydantic model).
  - State flags set but never read or reset on early-return paths. Was
    re-introduced once in RegisterView, but on 2026-07-04 he found and fixed
    it himself and applied the full pattern (reset + .disabled) across both
    views — transferring now. Still worth a glance in brand-new views.
  - Applies stated requirements partially: adopted requestLocation() when
    told to, but skipped the explicitly-mentioned didFailWithError
    requirement in the same instruction. Check multi-part instructions
    landed completely.
  - Silent failure paths with no user-facing error (RegisterView declares
    errorMessage but never renders it).
  - NEW: applying View-only property wrappers (@State) to properties of a
    plain/@Observable class (Location.swift).
  - Dead code hygiene: improving in edited files (LoginView was cleaned),
    but new files still ship with commented-out scaffolding (FunctionManager,
    Location.swift) and test credentials live in a comment atop LoginView.

## How to work with me
1. TEACH FIRST. Explain the why before the what. Prefer guiding me to write
   code over writing it for me. When I'm stuck, point me to an existing
   pattern in this codebase to imitate (e.g. "look how AuthManager does it")
   before showing new code.
2. Work layer by layer: have me build one piece, review it, THEN move on.
   Never stack new work on unverified code.
3. Ask me to predict behavior or find bugs myself when it's a good teaching
   moment (give hints, not answers, on the first pass).
4. Keep updating your read of my skill level as I work, and adjust depth
   accordingly. Tell me when you notice a gap or a leveled-up skill.
5. Flag Swift/iOS conventions and idioms as they come up — I want to learn
   professional habits (naming, private access control, modern APIs over
   legacy ones).
6. Before edits that touch both frontend and backend, explicitly check the
   contract between them (field names, optionality, snake_case).

## Current state / open tasks (as of 2026-07-19)
- [x] NSLocationWhenInUseUsageDescription — added via INFOPLIST_KEY in the
      target build settings (project.pbxproj). Location work is unblocked.
- [x] LoginView cleanup — isSubmitting early-return fixed, SecureField in,
      errorMessage shown in UI, dead URLSession code deleted,
      .disabled(isSubmitting) wired. Last follow-up: delete the
      test-credentials comment (alice/secret123) at the top of the file.
- [x] RegisterView — built AND review pass done: early-return resets
      isSubmitting, SecureField, errorMessage rendered, .disabled wired.
- [x] Location.swift conversion — done 2026-07-19 (it had regressed to
      startUpdatingLocation at some point; instructor re-fixed): requestLocation()
      now inside authorized cases, didFailWithError implemented (print-only),
      dead scaffolding removed. Remaining polish: denied/restricted and
      didFailWithError still print-only — needs user-facing errorMessage.
- [x] Restaurant details flow — built solo by Jax across both layers:
      place_details() implemented, GET /restaurant_details/{id},
      restaurantDetails Endpoint + RestaurantDTO + restaurantInfo + modal
      sheet in LocationView. snake_case contract bug (reviewSummary vs
      review_summary) found via hint and fixed by Jax himself.
- [x] Auth on feature endpoints — /find_restaurants (by Jax) and
      /restaurant_details (by instructor) now Depends(get_current_active_user);
      requiresAuth: true on both Swift Endpoints. This now actually exercises
      the 401-refresh path in APIClient.
- [ ] NEXT MILESTONE: end-to-end run with backend up (register -> login ->
      get location -> find_restaurants -> restaurant details sheet). Builds
      clean as of 2026-07-19 but NOT yet runtime-verified.
- [ ] Backend: rotate the Google Maps API key — STILL hardcoded in TWO
      places now (location.py:14 and :38; committed publicly, urgent, must be
      rotated in Google Cloud console — deleting from code isn't enough) —
      and move it + the hardcoded SECRET_KEY in auth.py to environment
      variables; /find_restaurants still ignores its `time` param.
- [ ] Hygiene backlog: alice/secret123 comment still atop LoginView;
      commented-out AuthManager scaffolding in FunctionManager.swift and dead
      lines in place_details(); /auth/logout never clears the refresh_token
      cookie (should use response.delete_cookie); stray semicolons in
      LocationView; ModalContentView ignores its restaurantName param (title
      shows the review text in .title font).

## Conventions in this codebase
- Swift: @Observable (not ObservableObject) for new model classes; @State
  private for view-owned state; lowerCamelCase vars; SecureField for
  passwords; no force-unwraps in new code.
- API JSON is snake_case; Swift side converts via JSONEncoder/Decoder.api.
- Tokens live in Keychain only, never UserDefaults.
