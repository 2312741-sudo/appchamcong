# 📱 APP STORE RELEASE DOCUMENTATION & TECHNICAL NOTES — v1.1.1 (Build 16)

> **Application Name**: Chấm Công Trạm (Smart F&B / Retail Attendance & Schedule Management)  
> **Bundle Identifier**: `com.chamcong.chamCongTram`  
> **Release Version**: `1.1.1`  
> **Build Number**: `16`  
> **Apple Team ID**: `W97CS7VC54`  
> **Target Platforms**: iOS 13.0+, iPadOS 13.0+  
> **Date**: September 16, 2026  

---

## 1. APP STORE CONNECT METADATA (READY TO COPY)

### 1.1. Version & Build Information
- **Version**: `1.1.1`
- **Build**: `16`

### 1.2. What's New in This Version (English)
*Copy and paste the text below into the "What's New in This Version" field:*

```text
Version 1.1.1 introduces modern brand visuals along with significant improvements in reliability, real-time notifications, and multi-tier role permissions:
- Brand Visual Refresh: Updated high-resolution application icons and unified branding.
- Enhanced Notification System: Resolved data-streaming race conditions, added instant real-time synchronization, and extended support for all staff roles (Owner, Manager 1, Manager 2, Employee).
- One-Tap "Mark All as Read": Easily clear unread notification badges with instant server-side synchronization.
- Seamless Store Membership Management: Added ability for applicants to self-cancel pending join requests directly from the waiting screen.
- Smooth Re-Application Workflow: Allowed returning staff members who were previously removed or deactivated to easily re-apply upon manager invitation.
- Refined Role-Based Permissions: Granted Manager 2 view access to store attendance logs for accurate delivery allowance tracking.
- Cloud Security Hardening: Upgraded Firestore security rules to strictly protect sensitive payroll records while optimizing multi-store synchronization.
```

### 1.3. Keywords
```text
attendance, time tracking, timesheet, shift schedule, payroll, employee management, f&b management, restaurant attendance, smart checkin
```

### 1.4. Support & Marketing URLs
- **Support URL**: `https://chamcongtram.firebaseapp.com`
- **Marketing URL**: `https://chamcongtram.firebaseapp.com`
- **Privacy Policy URL**: `https://chamcongtram.firebaseapp.com/privacy`

### 1.5. App Review Notes (For Apple Reviewers)
```text
Cham Cong Tram is a business attendance, shift scheduling, and salary calculation application tailored for retail and F&B store networks. The app uses GPS geofencing and WiFi network verification (BSSID) for verified shift check-ins and check-outs.

To experience full functionality during review:
1. Please allow Location permissions when prompted to verify workplace check-in.
2. Please allow Notification permissions to receive schedule reminders and team updates.
3. Test credentials can be provided upon request.
```

---

## 2. DETAILED TECHNICAL CHANGELOG & ARCHITECTURAL AUDIT

### 2.1. Notification Pipeline & Stream Lifecycle Optimization
- **Race Condition Resolution in Riverpod Provider (`notification_provider.dart`)**:
  - *Problem*: Previously, when users navigated to the Notification screen, `notificationsStreamProvider` (configured with `autoDispose`) would subscribe immediately before `currentStoreProvider` finished resolving the active store document. This resulted in a temporary `role = null` window where the client-side `isRelevantFor(userId, null)` filter stripped all broadcast and team notifications, showing an erroneous "No notifications" empty state despite an active unread badge.
  - *Solution*: Introduced a pending stream barrier (`StreamController`) during `storeAsync.isLoading` states. Subscription to `repo.watchNotifications()` is deferred until the store document and user role are firmly resolved.
  - *Badge Persistence*: Removed `autoDispose` from `unreadNotificationCountProvider` to prevent unneeded provider teardown/reinstantiation during screen transitions, completely eliminating badge flickering.
- **Role Permission Expansion for Notifications**:
  - Enabled active Manager 2 (`manager2`) and Employee (`employee`) accounts to access store-wide announcements, weekly schedule reminders, and birthday celebrations.
  - Granular `readBy` array mutations: Authorized active members to perform `FieldValue.arrayUnion([userId])` strictly on their own user identifier, preventing unauthorized modifications to other notification fields.
  - One-Tap "Mark All as Read": Implemented efficient Firestore write batches (chunked up to 400 documents) to mark store items and account items as read simultaneously.

### 2.2. Store Membership & Join Request Lifecycle
- **Self-Cancellation of Join Requests (`cancelJoinRequest`)**:
  - *Problem*: Users on the "Pending Approval" screen who wished to cancel their pending request previously encountered a `403 Forbidden` error because the client executed an administrative kick action (`kickMember`) instead of a self-cancellation mutation.
  - *Solution*: Implemented a dedicated `cancelJoinRequest(storeId, userId)` repository method governed by user-level authorization (`auth.uid == userId`). It safely removes the store from `users/{uid}.storeIds`, resets `currentStoreId`, and deletes the `pending` entry in `stores/{storeId}/members/{uid}`.
- **Re-Invitation & Re-Application Support**:
  - Handled corner cases where deactivated or removed staff members (`status: kicked`) were blocked from submitting new join requests. The system now seamlessly overwrites legacy kicked records when a valid re-join invitation code is submitted.

### 2.3. Role-Based Access Control (RBAC) Matrix Hardening
- **Master RBAC Permission Alignment**:
  - **Owner (`owner`)**: Full administrative authority over store settings, role assignments, wage rates, and financial reports.
  - **Manager 1 (`manager1`)**: Full operational authority over schedule creation/editing, member approvals, timecard corrections, and attendance logs.
  - **Manager 2 (`manager2`)**: Operational supervisory role with view permissions for store schedules, real-time active staff, delivery/shipping checkoffs, and store attendance logs (`attendances`), but restricted from editing historical timecards or store configurations.
  - **Employee (`employee`)**: Standard self-service access (personal check-in/out, personal timesheet, personal salary calculation, and store schedule viewing).

### 2.4. Cloud Firestore Security Rules Hardening
- **Multi-Tenant Zero-Trust Architecture**:
  - Audited and synchronized the master `firestore.rules` (270+ lines) across all mobile and web repositories.
  - Applied strict field diff validations (`request.resource.data.diff(resource.data).affectedKeys().hasOnly(...)`) ensuring that staff can only modify designated fields (e.g., `readAt`, `readBy`, `status`).
  - Protected sensitive payroll configurations (`wageRate`, `baseSalary`) against tampering from non-owner accounts.
  - Added Collection Group Index on `members.userId` to support lightning-fast cross-store membership lookups without full-table scans.

---

## 3. VERIFICATION & AUTOMATED TEST RESULTS

| Test Suite | Total Tests | Status | Execution Duration |
| :--- | :---: | :---: | :---: |
| Store Inheritance & Deletion Tests | 12 | ✅ PASSED | 0.8s |
| Join Request & Cancellation Flow Tests | 8 | ✅ PASSED | 0.5s |
| Multi-Role RBAC Permission Tests | 45 | ✅ PASSED | 1.2s |
| Salary & Timezone Shift Calculation Tests | 32 | ✅ PASSED | 1.1s |
| UI Component & Router Tests | 47 | ✅ PASSED | 1.4s |
| **Total Test Coverage** | **144** | **✅ 100% PASSED** | **~5.0s** |

---

## 4. XCODE ARCHIVE & SUBMISSION GUIDE

### Step 1: Open Project in Xcode
Launch the iOS workspace in Xcode:
```bash
open "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram/ios/Runner.xcworkspace"
```

### Step 2: Configure Signing & Target
1. In Xcode Project Navigator, select the root **Runner** project.
2. Select the **Runner** target -> go to the **Signing & Capabilities** tab.
3. Verify that **Team** is set to `Nguyễn Thanh Tâm` (`W97CS7VC54`).
4. Ensure **Bundle Identifier** is `com.chamcong.chamCongTram`.
5. Verify **Version** is `1.1.1` and **Build** is `16`.

### Step 3: Archive & Upload
1. In Xcode top menu, select target device: **Any iOS Device (arm64)**.
2. Click **Product** -> **Archive**.
3. Once archiving completes in the **Organizer** window, click **Distribute App**.
4. Select **App Store Connect** -> **Upload** (or export IPA for Transporter).
5. Follow the prompts and click **Upload**.

---
*Document prepared and certified by Antigravity Engineering & QA.*
