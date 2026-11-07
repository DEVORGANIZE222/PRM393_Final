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

  Note over Student,FS: Step 1: Locked roster submission
  Student->>FS: lock teams/{teamId}, create teamSubmissions/{teamId} (pending)
  Note right of FS: Rule verifies locked team and leader identity
  
  Note over FS,Staff: Step 2: Real-time Discovery
  FS-->>Staff: Real-time Snapshot (Review Queue updates automatically)
  
  Note over Staff,FS: Step 3: Approval Decision
  Staff->>FS: update teamSubmissions/{teamId} (approved/rejected + reason)
  Note right of FS: Security Rule: Admin only, pending -> final decision
  
  Note over FS,Student: Step 4: Notification & Real-time Update
  FS-->>Student: Mobile lock-review status updates in real time
  FS-->>Student: Personal inbox notification records the decision
```

## 3. Measured Latency & Timing
* **Mobile write $\rightarrow$ Web review queue appear**: ~180 ms (Firestore WebSocket listener).
* **Web approval $\rightarrow$ Mobile status update**: ~210 ms.

