# FlashDial Mobile App --- Project Context

> **Purpose of this document:** This file is the source of truth for
> developers working on the **FlashDial Android mobile application**.
> Keep it in the repository root as `PROJECT_CONTEXT.md` and update it
> when architecture or product decisions change.
>
> **Scope:** Android mobile app only. The web dashboard, its UI, and its
> implementation are intentionally outside the scope of this document.

------------------------------------------------------------------------

## 1. Product Overview

**Product name:** FlashDial\
**Product type:** Android SIM-based dialer and smart dialing assistant\
**Brand:** Aarambh Technologies

**Product description:**

FlashDial is a smart dialing assistant that lets users manage normal
cellular calls from their Android phone, with the ability to connect to
a desktop experience in a future/integrated workflow.

The Android application is first and foremost a **standalone phone
dialer**. It must be able to make and receive ordinary SIM-based calls
even when the user is offline or Firebase synchronization is
unavailable.

### Core product principles

1.  **Telephony comes first.** Making, receiving, and managing cellular
    calls must not depend on Firebase, the internet, or the Flutter UI
    being alive.
2.  **Android owns the call lifecycle.** Native Android telephony APIs
    are responsible for call state and call controls.
3.  **Flutter owns the main application experience.** Flutter provides
    the app screens, setup flow, settings, and other non-critical UI.
4.  **Cloud features are an optional layer.** Authentication, device
    status, remote commands, and synchronization must not become
    dependencies of local calling.
5.  **Respect Android platform rules.** Default-dialer role,
    permissions, notifications, background execution, and OEM
    restrictions must be handled according to the Android version and
    device.

------------------------------------------------------------------------

## 2. Primary Mobile App Responsibilities

The mobile app is responsible for:

-   Acting as the user's default Android phone/dialer app when the user
    grants the required role.
-   Displaying a dial pad and allowing the user to initiate outgoing
    cellular calls.
-   Receiving incoming-call callbacks and presenting an incoming-call
    experience.
-   Providing in-call controls such as answer, reject, end, mute, and
    speaker/audio-route selection where supported.
-   Showing the current call state and call duration.
-   Handling Android dial intents such as `ACTION_DIAL` and `tel:` URIs.
-   Continuing to manage calls when the Flutter screen is backgrounded
    or the device is locked.
-   Maintaining local app functionality when the device has no internet
    connection.
-   Optionally synchronizing device/call state with Firebase for
    connected experiences.

The app should not implement its own VoIP calling stack. Calls are
normal carrier/SIM calls handled by Android Telecom.

------------------------------------------------------------------------

## 3. User Experience and Main Flows

### 3.1 First launch and setup

1.  User opens FlashDial.
2.  App explains why it needs to become the default phone app.
3.  App checks whether FlashDial currently holds the default dialer
    role.
4.  If not, app asks the user to grant the role through the Android
    system flow.
5.  App checks and requests only the runtime permissions needed for
    enabled features.
6.  App displays setup status and explains any unavailable features.

Do not silently assume that a permission or role was granted. Always
verify the resulting platform state.

### 3.2 Outgoing call

1.  User enters a number in the dial pad or opens a number from a
    supported Android dial intent.
2.  App validates/normalizes the number without changing the user's
    intended destination.
3.  Native Android telephony integration initiates the cellular call.
4.  Android Telecom reports call-state changes.
5.  The app displays the appropriate dialing, connecting, active, and
    ended states.

### 3.3 Incoming call

1.  Android Telecom notifies the registered `InCallService` about a new
    call.
2.  Native call-management code records the call and its current state.
3.  FlashDial presents an incoming-call notification/UI, subject to
    Android's notification and full-screen-intent rules.
4.  User can answer or reject the call.
5.  The native layer performs the requested action and publishes updated
    state to the Flutter UI when available.

### 3.4 Ongoing call

The in-call experience should support, where the platform and call state
permit:

-   End call
-   Mute/unmute microphone
-   Speaker or other available audio endpoint selection
-   Call duration
-   Current call state
-   Hold/unhold, if supported and appropriate

Call duration should begin when the call becomes active/connected, not
when the user first taps the call button.

### 3.5 Offline operation

The following must continue to work without internet access:

-   Default dialer role and local dialer UI
-   SIM-based incoming and outgoing calls
-   Answer, reject, end, mute, and supported audio controls
-   Local call-state handling

Firebase authentication, remote commands, and cloud synchronization may
be unavailable while offline. Their failure must not block local
telephony.

------------------------------------------------------------------------

## 4. Technology Stack

### Mobile application

-   **Framework:** Flutter
-   **Language:** Dart
-   **Native Android layer:** Kotlin
-   **Architecture:** Feature-first Clean Architecture
-   **State management:** BLoC (`flutter_bloc`)
-   **Dependency injection:** GetIt
-   **Navigation:** GoRouter
-   **Platform bridge:** Flutter MethodChannel and EventChannel
-   **Cloud services (optional integration):** Firebase Authentication,
    Realtime Database, and Firebase Cloud Messaging

### Important implementation boundary

Flutter is not the owner of the Android call lifecycle.

Kotlin/Android must own the telephony lifecycle so calls continue to
work when:

-   Flutter UI is not visible.
-   The Flutter engine is detached.
-   The app is in the background.
-   The device is locked.

MethodChannel and EventChannel are bridges for communication with
Flutter while an engine is attached. They must not be the only place
where call state is stored or call actions are implemented.

------------------------------------------------------------------------

## 5. Android Telephony Design

### 5.1 Android Telecom APIs

Use Android's existing Telecom framework for normal SIM-based calls.

Key components:

-   `InCallService` --- receives callbacks for calls managed by Android
    Telecom.
-   `Call` --- represents a call and exposes its state and supported
    actions.
-   `TelecomManager` --- provides access to Telecom-related
    functionality and call placement APIs.
-   `RoleManager` --- checks and requests the default dialer role on
    supported Android versions.

**Use `InCallService` for managing existing carrier calls.** Do not
introduce a custom `ConnectionService` for ordinary SIM calls; that API
is intended for apps that provide their own calling connections, such as
VoIP.

### 5.2 Default dialer role

FlashDial is intended to request the Android default phone/dialer role.

Implementation must:

-   Check the current role before requesting it.
-   Launch the system role request flow.
-   Verify whether the role was actually granted.
-   Handle denial and cancellation gracefully.
-   Provide the required dialer entry points and user-facing call
    experiences.
-   Avoid claiming that FlashDial is the default dialer until Android
    confirms it.

The default dialer role is not equivalent to unrestricted access to
every call-related permission or capability.

### 5.3 Call controls

Use the Android `Call` APIs exposed to the `InCallService` for supported
operations, including:

-   Answer
-   Reject
-   Disconnect/end
-   Hold/unhold, when supported

Use the appropriate Android call-audio APIs for mute and audio routing.
On newer Android versions, use the current call-endpoint APIs where
applicable; for example, Android 14+ supports
`requestCallEndpointChange()`. Avoid relying on deprecated audio-routing
APIs for new implementations.

Always check the call's supported capabilities and current state before
attempting an action. Report the actual result rather than assuming that
a requested action succeeded.

### 5.4 Native call UI and notifications

Incoming and ongoing call experiences are time-sensitive and must not
depend on Flutter being active.

Use native Android components where necessary for reliable call
presentation, including:

-   Incoming call activity/UI
-   Ongoing call activity/UI
-   Call notification management
-   Full-screen intent when permitted and appropriate

Android versions impose restrictions on notifications, full-screen
intents, background activity launches, and foreground services.
Implement version-aware behavior and provide a useful notification
fallback when full-screen presentation is unavailable.

------------------------------------------------------------------------

## 6. Suggested Mobile Project Structure

The following is a proposed structure. Keep the native Android telephony
code separate from Flutter feature code.

``` text
flashdial_mobile/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/com/aarambh/flashdial/
│           ├── MainActivity.kt
│           ├── telecom/
│           │   ├── CallInCallService.kt
│           │   ├── CallManager.kt
│           │   ├── CallStateMapper.kt
│           │   └── CallAudioManager.kt
│           ├── dialer/
│           │   ├── DialerRoleManager.kt
│           │   └── DialerIntentHandler.kt
│           ├── ui/
│           │   ├── IncomingCallActivity.kt
│           │   ├── OngoingCallActivity.kt
│           │   └── CallNotificationManager.kt
│           ├── bridge/
│           │   ├── TelephonyMethodChannel.kt
│           │   └── TelephonyEventChannel.kt
│           └── models/
│               ├── NativeCall.kt
│               └── NativeCallState.kt
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   └── router/
│   ├── core/
│   │   ├── constants/
│   │   ├── di/
│   │   ├── errors/
│   │   ├── theme/
│   │   └── utils/
│   ├── features/
│   │   ├── device_setup/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── dialer/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── call_management/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   └── settings/
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   └── main.dart
├── test/
├── pubspec.yaml
└── PROJECT_CONTEXT.md
```

The package path shown above is a proposed convention. Confirm the final
Android application ID and Kotlin package before creating files.

------------------------------------------------------------------------

## 7. Flutter--Kotlin Communication

### 7.1 MethodChannel

Use a MethodChannel for Flutter-to-native requests. Suggested method
names:

  Method                Purpose
  --------------------- -----------------------------------------------
  `checkDialerRole`     Check whether FlashDial is the default dialer
  `requestDialerRole`   Launch the Android system role request
  `placeCall`           Request an outgoing cellular call
  `answerCall`          Answer a supported incoming call
  `rejectCall`          Reject a supported incoming call
  `endCall`             End the active call
  `setMuted`            Set microphone mute state
  `setAudioEndpoint`    Request a supported audio endpoint
  `getActiveCalls`      Return a snapshot of currently tracked calls

Use structured arguments and structured results. Return meaningful
errors for unsupported actions, missing calls, denied permissions, or
unavailable platform capabilities.

### 7.2 EventChannel

Use an EventChannel to send native call updates to Flutter while the
Flutter engine is attached.

Suggested event fields:

``` json
{
  "callId": "native-call-id",
  "phoneNumber": "+911234567890",
  "direction": "incoming",
  "state": "active",
  "timestamp": "ISO-8601 timestamp",
  "isMuted": false,
  "audioEndpoint": "earpiece"
}
```

This is an illustrative event shape, not a fixed Android API model. Keep
the Dart and Kotlin event contracts versioned and consistent.

EventChannel is not a durable message queue. Flutter must be able to
request a current call snapshot after attaching or resuming, rather than
relying only on events it may have missed.

------------------------------------------------------------------------

## 8. Suggested Dart Domain Models

### Call status

``` dart
enum CallStatus {
  idle,
  ringing,
  dialing,
  connecting,
  active,
  holding,
  disconnected,
  failed,
}
```

### Call direction

``` dart
enum CallDirection {
  incoming,
  outgoing,
}
```

### Call entity

``` dart
class CallEntity {
  final String id;
  final String phoneNumber;
  final String? contactName;
  final CallDirection direction;
  final CallStatus status;
  final DateTime? startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final bool isMuted;
  final bool isSpeakerOn;

  const CallEntity({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    required this.direction,
    required this.status,
    this.startedAt,
    this.connectedAt,
    this.endedAt,
    required this.isMuted,
    required this.isSpeakerOn,
  });
}
```

Adapt the model to actual native capabilities. Do not assume that every
Android device exposes the same audio endpoints or call capabilities.

------------------------------------------------------------------------

## 9. Branding and Design System

FlashDial should visually align with the Aarambh Technologies brand and
the approved FlashDial logo.

The logo uses a dark navy background, metallic silver/white lettering,
and vivid orange orbital/lightning elements. The following are practical
UI theme values sampled/approximated from that visual direction. They
are design tokens, not official color values extracted from a vector
brand file.

### Core colors

  -----------------------------------------------------------------------
  Token                   Hex                     Usage
  ----------------------- ----------------------- -----------------------
  **Primary**             `#07152E`               Main brand color, app
                                                  bars, navigation, dark
                                                  backgrounds

  **Primary dark**        `#030B1A`               Deep background and
                                                  high-contrast surfaces

  **Secondary**           `#FF6A00`               Main orange brand
                                                  accent, primary
                                                  actions, selected
                                                  states

  **Secondary bright**    `#FF9D00`               Highlights, gradients,
                                                  active indicators

  **Accent gold**         `#FFC247`               Subtle glow/highlight
                                                  accents; use sparingly

  **Surface**             `#101F38`               Cards, sheets, elevated
                                                  dark surfaces

  **Surface light**       `#F4F6FA`               Light theme surfaces,
                                                  if/when a light theme
                                                  is introduced

  **Text on dark**        `#F5F7FB`               Primary text on dark
                                                  backgrounds

  **Secondary text**      `#AAB5C5`               Supporting text on dark
                                                  backgrounds

  **Dark text**           `#111827`               Text on light surfaces

  **Border**              `#263750`               Dividers and subtle
                                                  outlines

  **Success**             `#22A06B`               Successful states

  **Error**               `#E5484D`               Errors and destructive
                                                  states

  **Warning**             `#F5A524`               Warnings
  -----------------------------------------------------------------------

**Primary color:** `#07152E`\
**Secondary color:** `#FF6A00`

### Design guidance

-   Use navy as the main structural color and orange to draw attention
    to important actions.
-   Use orange for the primary dial/call action and active selection,
    but do not use it for every icon or label.
-   Reserve green for successful/connected states and red for
    reject/end/destructive actions.
-   Maintain strong contrast and readable typography.
-   Keep dial-pad numbers large, well-spaced, and easy to tap.
-   Call controls should have clear labels or accessible semantics, not
    rely on color alone.
-   Use gradients and glow effects sparingly. The app UI should remain
    clean and usable even though the logo has a glossy 3D treatment.
-   Support different screen sizes, font scaling, and Android
    accessibility settings.

------------------------------------------------------------------------

## 10. Permissions and Android Manifest Considerations

Declare only the permissions required by implemented features. The final
manifest must be reviewed against the app's actual minimum SDK, target
SDK, and Android version support.

Potential permissions and declarations include:

-   `android.permission.CALL_PHONE` --- only if the implementation uses
    an API that requires it to place calls.
-   `android.permission.POST_NOTIFICATIONS` --- runtime permission on
    Android 13+ for normal notifications.
-   `android.permission.USE_FULL_SCREEN_INTENT` --- subject to Android
    version rules and special access/policy restrictions.
-   `android.permission.READ_CONTACTS` --- only if contact lookup is
    implemented.
-   Call-related service declaration for `InCallService`, protected by
    `android.permission.BIND_INCALL_SERVICE`, with the required Telecom
    intent filter and metadata.

Important:

-   Do not assume that requesting the default dialer role automatically
    grants every permission.
-   Do not add call-log permissions unless a clearly defined feature
    requires them.
-   `READ_CALL_LOG` is restricted/hard-restricted in relevant Android
    contexts; sideloading an APK does not guarantee it can be granted.
-   Ask for runtime permissions in context and explain why they are
    needed.
-   Handle denied, revoked, or restricted permissions without crashing.
-   Validate the manifest against current Android documentation before
    release.

------------------------------------------------------------------------

## 11. Firebase and Remote Integration Boundary

Firebase is an optional synchronization and remote-control layer. It
must never be the authority for the local Android call lifecycle.

Planned Firebase services:

-   **Firebase Authentication:** identify the signed-in user.
-   **Realtime Database:** share device presence and live call state,
    and receive remote action requests.
-   **Firebase Cloud Messaging:** deliver remote command notifications
    when the app is not actively connected.

Potential future responsibilities:

-   Device registration and status
-   Online/offline presence
-   Remote dial requests
-   Remote answer/reject/end requests, subject to Android platform
    capabilities and user experience requirements
-   Call-state synchronization
-   Call-history synchronization, if explicitly approved and supported

### Reliability and security rules

-   Validate every remote command before acting on it.
-   Associate devices with authenticated users.
-   Do not trust a phone number, command, user ID, or device ID supplied
    by an untrusted client without authorization checks.
-   Use unique command IDs and timestamps to prevent duplicate
    execution.
-   Expire stale commands.
-   Acknowledge commands only after native code has validated and
    attempted the operation.
-   Record command failures and reasons without exposing sensitive
    information.
-   Do not store call audio or stream microphone audio to Firebase.
-   Minimize retention of phone numbers and call metadata; define access
    rules and retention before enabling cloud call history.

FCM delivery and background execution are conditional. High-priority
messages, foreground services, boot receivers, and background activity
launches are all subject to Android restrictions and device/OEM
behavior. Do not promise guaranteed remote call control when the app is
force-stopped, the device is offline, or the OS blocks background
execution.

------------------------------------------------------------------------

## 12. Reliability, Lifecycle, and Edge Cases

Developers must account for:

-   Flutter engine not attached when a call arrives.
-   App process recreation.
-   Activity recreation and configuration changes.
-   Device locked or screen off.
-   No internet connection.
-   Firebase unavailable or user signed out.
-   User revokes permissions or changes the default dialer.
-   SIM unavailable, disabled, or out of service.
-   Multiple call states, call waiting, and call hold where supported.
-   Bluetooth headset and other audio endpoints.
-   Android version differences.
-   OEM battery optimization and background restrictions.
-   Native service or activity failure.

Keep native call state as the operational source of truth. Flutter
should rebuild its UI from a native snapshot after reconnecting.

Do not promise that FlashDial can prevent the operating system from
terminating it. Force-stop behavior, OEM restrictions, and
emergency-call handling remain under Android/system control. The
preinstalled/system dialer may be used by Android in certain fallback or
emergency scenarios.

------------------------------------------------------------------------

## 13. Development Milestones

### Milestone 1 --- Android telephony proof of concept

Do not begin with Firebase or the remote dashboard. First prove that
FlashDial can function as a reliable local dialer.

-   [ ] Create the Flutter project and confirm application ID/package.
-   [ ] Configure the Android manifest and Telecom service.
-   [ ] Implement default dialer role check/request.
-   [ ] Implement `InCallService` and native call tracking.
-   [ ] Detect incoming calls on a physical Android device.
-   [ ] Present incoming call UI with answer/reject.
-   [ ] Initiate outgoing SIM calls.
-   [ ] Present ongoing call UI.
-   [ ] Implement end, mute, and supported audio endpoint controls.
-   [ ] Handle locked-screen and notification behavior.
-   [ ] Verify operation without internet.
-   [ ] Test process/activity recreation and permission denial.

### Milestone 2 --- Flutter application integration

-   [ ] Implement MethodChannel contracts.
-   [ ] Implement EventChannel call-state updates.
-   [ ] Add native snapshot retrieval.
-   [ ] Build Flutter dialer UI.
-   [ ] Build call-management UI.
-   [ ] Add device setup and permission status screens.
-   [ ] Add BLoC state management and dependency injection.
-   [ ] Add automated tests for Dart-side state and mapping.

### Milestone 3 --- Optional Firebase integration

-   [ ] Add Firebase Authentication.
-   [ ] Register and associate the Android device with the signed-in
    user.
-   [ ] Add Realtime Database device presence and call-state sync.
-   [ ] Add FCM command delivery.
-   [ ] Add command validation, expiry, deduplication, and
    acknowledgements.
-   [ ] Test offline, signed-out, stale-command, and background
    restrictions.

### Milestone 4 --- Hardening and release

-   [ ] Test on multiple physical Android devices and Android versions.
-   [ ] Test SIM/network loss and call waiting.
-   [ ] Test Bluetooth and speaker routing.
-   [ ] Test denied/revoked permissions and default-dialer role removal.
-   [ ] Review privacy, data minimization, and security rules.
-   [ ] Review Android distribution and Play policy requirements, if
    publishing.
-   [ ] Add crash reporting and safe diagnostic logging.
-   [ ] Document known device/OS limitations.

------------------------------------------------------------------------

## 14. Testing Requirements

**Use physical Android devices with active SIM cards.** An emulator
alone cannot validate the complete cellular-call experience.

At minimum, test:

  -----------------------------------------------------------------------
  Scenario                            Expected behavior
  ----------------------------------- -----------------------------------
  Outgoing call with network          Android places a normal SIM call

  Incoming call, app open             FlashDial presents incoming-call
                                      controls

  Incoming call, screen locked        Native notification/UI behaves
                                      according to Android permissions
                                      and policies

  Answer and end                      Native Telecom state updates
                                      correctly

  Reject incoming call                Call is rejected and UI is
                                      dismissed/updated

  Mute and speaker                    Requested supported audio state is
                                      applied

  No internet                         Local cellular calling remains
                                      functional

  Firebase unavailable                Local calling remains functional

  Flutter UI detached                 Native call lifecycle continues

  Default dialer role removed         App detects the change and guides
                                      the user

  Permission denied                   App explains the limitation and
                                      remains stable

  Unsupported audio endpoint          App handles it gracefully without
                                      crashing
  -----------------------------------------------------------------------

Never use a successful UI animation as proof that a telephony action
succeeded. Confirm the result from Android Telecom callbacks/state.

------------------------------------------------------------------------

## 15. Initial Dependency Guidance

Keep dependencies minimal until each feature requires them.

Suggested Flutter packages:

-   `flutter_bloc`
-   `equatable`
-   `get_it`
-   `go_router`

Add Firebase packages only when the corresponding cloud milestone
begins. Avoid adding a generic Flutter telephony plugin without first
confirming that it supports the required default-dialer and
`InCallService` behavior. The core telephony integration is expected to
be implemented in Kotlin.

------------------------------------------------------------------------

## 16. Engineering Rules for Future Developers

1.  Do not move core call lifecycle ownership into Dart.
2.  Do not make local calling dependent on Firebase or network
    availability.
3.  Do not assume permissions, roles, or call capabilities; check them
    at runtime.
4.  Do not use `ConnectionService` for ordinary SIM calls managed by
    Android Telecom.
5.  Do not assume Flutter events are durable; provide a native state
    snapshot API.
6.  Do not claim a call action succeeded until Android confirms the
    resulting state.
7.  Do not log full phone numbers or sensitive call metadata in
    production logs.
8.  Keep Android-version-specific behavior isolated in the native layer.
9.  Keep the Flutter code feature-first and separate presentation,
    domain, and data responsibilities.
10. Update this document whenever a product or architecture decision
    changes.

------------------------------------------------------------------------

## 17. Open Decisions to Confirm Before Production

The following are not finalized and must be agreed before
implementation/release:

-   Final Android application ID and Kotlin package name.
-   Minimum and target SDK versions.
-   Supported Android version/device matrix.
-   Whether contacts are read from the device and whether contact
    permissions are required.
-   Whether call history is stored locally, synchronized, or both.
-   Whether multiple SIM selection must be supported in the first
    release.
-   Whether call waiting/hold and conference-call scenarios are in
    scope.
-   Whether the app will be distributed through Google Play, private
    distribution, or both.
-   Firebase data schema, retention policy, and authorization rules.
-   Exact remote actions permitted from a connected desktop session.

Until these decisions are confirmed, treat the related implementation
details as configurable design choices rather than fixed requirements.

------------------------------------------------------------------------

**Document status:** Initial project context\
**Product:** FlashDial Android Mobile App\
**Brand owner:** Aarambh Technologies
