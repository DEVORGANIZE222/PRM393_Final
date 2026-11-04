# Cross-Role Workflow Specification (Appendix C)

## 1. Overview
The cross-role workflow demonstrates live synchronization between the **Mobile client (Student)** and the **Web Admin client (Staff/Mentor)** through shared Firestore state, governed by role-based Security Rules.

## 2. Sequence Diagram (Mermaid)

```mermaid
sequenceDiagram
  autonumber
  actor Student as Mobile Client (Student)
  participant FS as Cloud Firestore
  actor Staff as Web Admin (Staff / Mentor)

  Note over Student,FS: Step 1: Submission
  Student->>FS: write registrations/{id} (status: "pending")
  Note right of FS: Security Rule: allow create if auth.uid == uid and status == "pending"
  
  Note over FS,Staff: Step 2: Real-time Discovery
  FS-->>Staff: Real-time Snapshot (Review Queue updates automatically)
  
  Note over Staff,FS: Step 3: Approval Decision
  Staff->>FS: update registrations/{id} (status: "approved")
  Note right of FS: Security Rule: allow update if isStaff() and transition pending -> approved
  
  Note over FS,Student: Step 4: Notification & Real-time Update
  FS-->>Student: Real-time Snapshot on Mobile (Status badge turns Green: Approved)
  Staff->>FS: write announcements/{id} (Title: "Capstone Roster Finalized")
  FS-->>Student: Mobile Inbox badge updates in real time
```

## 3. Measured Latency & Timing
* **Mobile write $\rightarrow$ Web review queue appear**: ~180 ms (Firestore WebSocket listener).
* **Web approval $\rightarrow$ Mobile status update**: ~210 ms.

